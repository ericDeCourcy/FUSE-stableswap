// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

//import "./contracts-v3_4/math/SafeMath.sol"; //removed since already present in SafeERC20.sol
import "../contracts-v3_4/token/ERC20/SafeERC20.sol";
import "../contracts-v3_4/proxy/Clones.sol";
import "../contracts-upgradeable-v3_4/utils/ReentrancyGuardUpgradeable.sol";
import "../OwnerPausableUpgradeable.sol";
import "./SwapUtilsV4.sol";
import "./AmplificationUtilsV4.sol";
import "./LPRewardsV4.sol";

/**ext:sol
 * @title Swap - A StableSwap implementation in solidity.
 * @notice This contract is responsible for custody of closely pegged assets (eg. group of stablecoins)
 * and automatic market making system. Users become an LP (Liquidity Provider) by depositing their tokens
 * in desired ratios for an exchange of the pool token that represents their share of the pool.
 * Users can burn pool tokens and withdraw their share of token(s).
 *
 * Each time a swap between the pooled tokens happens, a set fee incurs which effectively gets
 * distributed to the LPs.
 *
 * In case of emergencies, admin can pause additional deposits, swaps, or single-asset withdraws - which
 * stops the ratio of the tokens in the pool from changing.
 * Users can always withdraw their tokens via multi-asset withdraws.
 *
 * @dev Most of the logic is stored as a library `SwapUtils` for the sake of reducing contract's
 * deployment size.
 */

// Only difference between V1 and V2 is that V2 incorporates rewards staking.
//     - V2 deploys a rewards contract from which users can claim rewards
//     - V2 hooks into said rewards contract every time an LP token balance changes
//
// V3 differs from V2 in that it implements a "cap" for the number of LP tokens in circulation which can be adjusted by the pool owner
// 
// V4 adds a swapExactOut function, which allows you to specify an exact output and send in variable number of tokens
//  This allows for integration into uniswap style routers
contract SwapV4 is OwnerPausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using SwapUtilsV4 for SwapUtilsV4.Swap;
    using AmplificationUtilsV4 for SwapUtilsV4.Swap;

    // Struct storing data responsible for automatic market maker functionalities. In order to
    // access this data, this contract uses SwapUtils library. For more details, see SwapUtilsV4.sol
    SwapUtilsV4.Swap public swapStorage;

    // Maps token address to an index in the pool. Used to prevent duplicate tokens in the pool.
    // getTokenIndex function also relies on this mapping to retrieve token index.
    mapping(address => uint8) private tokenIndexes;

    // address of LPRewards contract
    address public lpRewardsAddress;

    /*** EVENTS ***/

    // events replicated from SwapUtils to make the ABI easier for dumb
    // clients
    event TokenSwap(
        address indexed buyer,
        uint256 tokensSold,
        uint256 tokensBought,
        uint128 soldId,
        uint128 boughtId
    );
    event AddLiquidity(
        address indexed provider,
        uint256[] tokenAmounts,
        uint256[] fees,
        uint256 invariant,
        uint256 lpTokenSupply
    );
    event RemoveLiquidity(
        address indexed provider,
        uint256[] tokenAmounts,
        uint256 lpTokenSupply
    );
    event RemoveLiquidityOne(
        address indexed provider,
        uint256 lpTokenAmount,
        uint256 lpTokenSupply,
        uint256 boughtId,
        uint256 tokensBought
    );
    event RemoveLiquidityImbalance(
        address indexed provider,
        uint256[] tokenAmounts,
        uint256[] fees,
        uint256 invariant,
        uint256 lpTokenSupply
    );
    event NewAdminFee(uint256 newAdminFee);
    event NewSwapFee(uint256 newSwapFee);
    event RampA(
        uint256 oldA,
        uint256 newA,
        uint256 initialTime,
        uint256 futureTime
    );
    event StopRampA(uint256 currentA, uint256 time);

    /**
     * @notice Initializes this Swap contract with the given parameters.
     * This will also clone a LPToken contract that represents users'
     * LP positions. The owner of LPToken will be this contract - which means
     * only this contract is allowed to mint/burn tokens.
     *
     * @param _pooledTokens an array of ERC20s this pool will accept
     * @param decimals the decimals to use for each pooled token,
     * eg 8 for WBTC. Cannot be larger than POOL_PRECISION_DECIMALS
     * @param lpTokenName the long-form name of the token to be deployed
     * @param lpTokenSymbol the short symbol for the token to be deployed
     * @param _a the amplification coefficient * n * (n - 1). See the
     * StableSwap paper for details
     * @param _fee default swap fee to be initialized with
     * @param _adminFee default adminFee to be initialized with
     * @param lpTokenTargetAddress the address of an existing LPToken contract to use as a target
     */
    function initialize(
        IERC20[] memory _pooledTokens,
        uint8[] memory decimals,
        string memory lpTokenName,
        string memory lpTokenSymbol,
        uint256 _a,
        uint256 _fee,
        uint256 _adminFee,
        address lpTokenTargetAddress,
        address lpRewardsTargetAddress
    ) public virtual initializer returns(address newLpToken){
        __OwnerPausable_init();
        __ReentrancyGuard_init();
        // Check _pooledTokens and precisions parameter
        require(_pooledTokens.length > 1, "_pooledTokens.length <= 1");
        require(_pooledTokens.length <= 32, "_pooledTokens.length > 32");
        require(
            _pooledTokens.length == decimals.length,
            "_pooledTokens decimals mismatch"
        );

        uint256[] memory precisionMultipliers = new uint256[](decimals.length);

        for (uint8 i = 0; i < _pooledTokens.length; i++) {
            if (i > 0) {
                // Check if index is already used. Check if 0th element is a duplicate.
                require(
                    tokenIndexes[address(_pooledTokens[i])] == 0 &&
                        _pooledTokens[0] != _pooledTokens[i],
                    "Duplicate tokens"
                );
            }
            require(
                address(_pooledTokens[i]) != address(0),
                "The 0 address isn't an ERC-20"
            );
            require(
                decimals[i] <= SwapUtilsV4.POOL_PRECISION_DECIMALS,
                "Token decimals exceeds max"
            );
            precisionMultipliers[i] =
                10 **
                    uint256(SwapUtilsV4.POOL_PRECISION_DECIMALS).sub(
                        uint256(decimals[i])
                    );
            tokenIndexes[address(_pooledTokens[i])] = i;
        }

        // Check _a, _fee, _adminFee parameters
        require(_a < AmplificationUtilsV4.MAX_A, "_a exceeds maximum");
        require(_fee < SwapUtilsV4.MAX_SWAP_FEE, "_fee exceeds maximum");
        require(
            _adminFee < SwapUtilsV4.MAX_ADMIN_FEE,
            "_adminFee exceeds maximum"
        );

        // Clone and initialize a LPToken contract
        LPTokenV4 lpToken = LPTokenV4(Clones.clone(lpTokenTargetAddress));
        require(
            lpToken.initialize(lpTokenName, lpTokenSymbol),
            "could not init lpToken clone"
        );

        // Clone and initialize a LPRewards contract
        LPRewardsV4 lpRewards = LPRewardsV4(Clones.clone(lpRewardsTargetAddress));
        lpRewardsAddress = address(lpRewards);
        require(
            lpRewards.initialize(address(lpToken), tx.origin),  //Note: ownership is transferred to tx.origin - this will give ownership of the rewards contract to the sender who created this pool
            "could not init lpRewards clone"
        );
        
        lpRewards.transferOwnership(msg.sender);  
         
        



        // Initialize swapStorage struct
        swapStorage.lpToken = lpToken;
        swapStorage.pooledTokens = _pooledTokens;
        swapStorage.tokenPrecisionMultipliers = precisionMultipliers;
        swapStorage.balances = new uint256[](_pooledTokens.length);
        swapStorage.initialA = _a.mul(AmplificationUtilsV4.A_PRECISION);
        swapStorage.futureA = _a.mul(AmplificationUtilsV4.A_PRECISION);
        swapStorage.swapFee = _fee;
        swapStorage.adminFee = _adminFee;
        
        // new in V3 - initialize lpCap at 100 LP Tokens
        swapStorage.lpCap = 100e18;

        return address(lpToken);
    }

    /*** MODIFIERS ***/

    /**
     * @notice Modifier to check deadline against current timestamp
     * @param deadline latest timestamp to accept this transaction
     */
    modifier deadlineCheck(uint256 deadline) {
        require(block.timestamp <= deadline, "Deadline not met");
        _;
    }

    /*** VIEW FUNCTIONS ***/

    /**
     * @notice Return A, the amplification coefficient * n * (n - 1)
     * @dev See the StableSwap paper for details
     * @return A parameter
     */
    function getA() external view virtual returns (uint256) {
        return swapStorage.getA();
    }

    /**
     * @notice Return A in its raw precision form
     * @dev See the StableSwap paper for details
     * @return A parameter in its raw precision form
     */
    function getAPrecise() external view virtual returns (uint256) {
        return swapStorage.getAPrecise();
    }

    /**
     * @notice Return address of the pooled token at given index. Reverts if tokenIndex is out of range.
     * @param index the index of the token
     * @return address of the token at given index
     */
    function getToken(uint8 index) public view virtual returns (IERC20) {
        require(index < swapStorage.pooledTokens.length, "Out of range");
        return swapStorage.pooledTokens[index];
    }

    /**
     * @notice Return the index of the given token address. Reverts if no matching
     * token is found.
     * @param tokenAddress address of the token
     * @return the index of the given token address
     */
    function getTokenIndex(address tokenAddress)
        public
        view
        virtual
        returns (uint8)
    {
        uint8 index = tokenIndexes[tokenAddress];
        require(
            address(getToken(index)) == tokenAddress,
            "Token does not exist"
        );
        return index;
    }


    /**
     * @notice Return current balance of the pooled token at given index
     * @param index the index of the token
     * @return current balance of the pooled token at given index with token's native precision
     */
    function getTokenBalance(uint8 index)
        external
        view
        virtual
        returns (uint256)
    {
        require(index < swapStorage.pooledTokens.length, "Index out of range");
        return swapStorage.balances[index];
    }

    /**
     * @notice Get the virtual price, to help calculate profit
     * @return the virtual price, scaled to the POOL_PRECISION_DECIMALS
     */
    function getVirtualPrice() external view virtual returns (uint256) {
        return swapStorage.getVirtualPrice();
    }

    /**
     * @notice Calculate amount of tokens you receive on swap
     * @param tokenIndexFrom the token the user wants to sell
     * @param tokenIndexTo the token the user wants to buy
     * @param dx the amount of tokens the user wants to sell. If the token charges
     * a fee on transfers, use the amount that gets transferred after the fee.
     * @return amount of tokens the user will receive
     */
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view virtual returns (uint256) {
        return swapStorage.calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
    }

    /**
     * @notice Calculates how much you have to transfer in to get dy tokens out
     * @param tokenIndexFrom Index of token user will send in for swap
     * @param tokenIndexTo Index of token user will recieve
     * @param dy Amount of token "to" user desires
     * @return The amount of tokenIndexFrom user will need to send in
     */
    function calculateSwapExactOut(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dy
    ) external view virtual returns (uint256) {
        return swapStorage.calculateSwapExactOut(tokenIndexFrom, tokenIndexTo, dy);
    }

    /**
     * @notice A simple method to calculate prices from deposits or
     * withdrawals, excluding fees but including slippage. This is
     * helpful as an input into the various "min" parameters on calls
     * to fight front-running
     *
     * @dev This shouldn't be used outside frontends for user estimates.
     *
     * @param account address that is depositing or withdrawing tokens
     * @param amounts an array of token amounts to deposit or withdrawal,
     * corresponding to pooledTokens. The amount should be in each
     * pooled token's native precision. If a token charges a fee on transfers,
     * use the amount that gets transferred after the fee.
     * @param deposit whether this is a deposit or a withdrawal
     * @return token amount the user will receive
     */
    function calculateTokenAmount(
        address account,
        uint256[] calldata amounts,
        bool deposit
    ) external view virtual returns (uint256) {
        return swapStorage.calculateTokenAmount(account, amounts, deposit);
    }

    /**
     * @notice A simple method to calculate amount of each underlying
     * tokens that is returned upon burning given amount of LP tokens
     * @param account the address that is withdrawing tokens
     * @param amount the amount of LP tokens that would be burned on withdrawal
     * @return array of token balances that the user will receive
     */
    function calculateRemoveLiquidity(address account, uint256 amount)
        external
        view
        virtual
        returns (uint256[] memory)
    {
        return swapStorage.calculateRemoveLiquidity(account, amount);
    }

    /**
     * @notice Calculate the amount of underlying token available to withdraw
     * when withdrawing via only single token
     * @param account the address that is withdrawing tokens
     * @param tokenAmount the amount of LP token to burn
     * @param tokenIndex index of which token will be withdrawn
     * @return availableTokenAmount calculated amount of underlying token
     * available to withdraw
     */
    function calculateRemoveLiquidityOneToken(
        address account,
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view virtual returns (uint256 availableTokenAmount) {
        return
            swapStorage.calculateWithdrawOneToken(
                account,
                tokenAmount,
                tokenIndex
            );
    }

    /**
     * @notice This function reads the accumulated amount of admin fees of the token with given index
     * @param index Index of the pooled token
     * @return admin's token balance in the token's precision
     */
    function getAdminBalance(uint256 index)
        external
        view
        virtual
        returns (uint256)
    {
        return swapStorage.getAdminBalance(index);
    }

    /*** STATE MODIFYING FUNCTIONS ***/

    /**
     * @notice Swap two tokens using this pool
     * @param tokenIndexFrom the token the user wants to swap from
     * @param tokenIndexTo the token the user wants to swap to
     * @param dx the amount of tokens the user wants to swap from
     * @param minDy the min amount the user would like to receive, or revert.
     * @param deadline latest timestamp to accept this transaction
     * @return amount of token user received on swap
     */
    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    )
        external
        virtual
        nonReentrant
        whenNotPaused
        deadlineCheck(deadline)
        returns (uint256)
    {
        return swapStorage.swap(tokenIndexFrom, tokenIndexTo, dx, minDy);
    }

    /**
     * @notice Conducts swap to get a specified amount out
     * @param tokenIndexFrom Index of the token the user sends in for swap
     * @param tokenIndexTo Index of the token the user recieves from swap
     * @param dy Amount of token "to" user wants
     * @param maxDx Maximum amount of token "from" user is willing to pay
     * @param deadline latest timestamp to accept this transaction
     * @return dx The number of tokens paid in
     */
    function swapExactOut(
        uint8 tokenIndexFrom, 
        uint8 tokenIndexTo,
        uint256 dy,
        uint256 maxDx, 
        uint256 deadline
    )
        external
        virtual
        nonReentrant
        whenNotPaused
        deadlineCheck(deadline)
        returns (uint256)
    {
        return swapStorage.swapExactOut(tokenIndexFrom, tokenIndexTo, dy, maxDx);
    }

    /**
     * @notice Add liquidity to the pool with the given amounts of tokens
     * @param amounts the amounts of each token to add, in their native precision
     * @param minToMint the minimum LP tokens adding this amount of liquidity
     * should mint, otherwise revert. Handy for front-running mitigation
     * @param deadline latest timestamp to accept this transaction
     * @return amount of LP token user minted and received
     */
    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    )
        external
        virtual
        nonReentrant
        whenNotPaused
        deadlineCheck(deadline)
        returns (uint256)
    {
        return swapStorage.addLiquidity(amounts, minToMint);
    }

    /**
     * @notice Burn LP tokens to remove liquidity from the pool. 
     * @dev Liquidity can always be removed, even when the pool is paused.
     * @param amount the amount of LP tokens to burn
     * @param minAmounts the minimum amounts of each token in the pool
     *        acceptable for this burn. Useful as a front-running mitigation
     * @param deadline latest timestamp to accept this transaction
     * @return amounts of tokens user received
     */
    function removeLiquidity(
        uint256 amount,
        uint256[] calldata minAmounts,
        uint256 deadline
    )
        external
        virtual
        nonReentrant
        deadlineCheck(deadline)
        returns (uint256[] memory)
    {
        return swapStorage.removeLiquidity(amount, minAmounts);
    }

    /**
     * @notice Remove liquidity from the pool all in one token. 
     * @param tokenAmount the amount of the token you want to receive
     * @param tokenIndex the index of the token you want to receive
     * @param minAmount the minimum amount to withdraw, otherwise revert
     * @param deadline latest timestamp to accept this transaction
     * @return amount of chosen token user received
     */
    function removeLiquidityOneToken(
        uint256 tokenAmount,
        uint8 tokenIndex,
        uint256 minAmount,
        uint256 deadline
    )
        external
        virtual
        nonReentrant
        whenNotPaused
        deadlineCheck(deadline)
        returns (uint256)
    {
        return
            swapStorage.removeLiquidityOneToken(
                tokenAmount,
                tokenIndex,
                minAmount
            );
    }

    /**
     * @notice Remove liquidity from the pool, weighted differently than the
     * pool's current balances. 
     * @param amounts how much of each token to withdraw
     * @param maxBurnAmount the max LP token provider is willing to pay to
     * remove liquidity. Useful as a front-running mitigation.
     * @param deadline latest timestamp to accept this transaction
     * @return amount of LP tokens burned
     */
    function removeLiquidityImbalance(
        uint256[] calldata amounts,
        uint256 maxBurnAmount,
        uint256 deadline
    )
        external
        virtual
        nonReentrant
        whenNotPaused
        deadlineCheck(deadline)
        returns (uint256)
    {
        return swapStorage.removeLiquidityImbalance(amounts, maxBurnAmount);
    }

    /*** ADMIN FUNCTIONS ***/
    
    /*
    * @notice Updates the reward contract's accounting for two accounts.
    * @dev Typically called by the LPToken contract with both accounts being the sender and reciever of any transfer.
    * @dev Mints and burns also count as "transfers"
    */
    function updateRewardsTwoAccounts(address _account1, address _account2) 
        external
    {
        LPRewardsV4(lpRewardsAddress).updateAllRewards(_account1);
        LPRewardsV4(lpRewardsAddress).updateAllRewards(_account2);
    }

    /**
     * @notice Withdraw all admin fees to the contract owner
     */
    function withdrawAdminFees() external onlyOwner {
        swapStorage.withdrawAdminFees(owner());
    }

    /**
     * @notice Update the admin fee. Admin fee takes portion of the swap fee.
     * @param newAdminFee new admin fee to be applied on future transactions
     */
    function setAdminFee(uint256 newAdminFee) external onlyOwner {
        swapStorage.setAdminFee(newAdminFee);
    }

    /**
     * @notice Update the swap fee to be applied on swaps
     * @param newSwapFee new swap fee to be applied on future transactions
     */
    function setSwapFee(uint256 newSwapFee) external onlyOwner {
        swapStorage.setSwapFee(newSwapFee);
    }

    /**
     * @notice Start ramping up or down A parameter towards given futureA and futureTime
     * Checks if the change is too rapid, and commits the new A value only when it falls under
     * the limit range.
     * @param futureA the new A to ramp towards
     * @param futureTime timestamp when the new A should be reached
     */
    function rampA(uint256 futureA, uint256 futureTime) external onlyOwner {
        swapStorage.rampA(futureA, futureTime);
    }

    /**
     * @notice Stop ramping A immediately. Reverts if ramp A is already stopped.
     */
    function stopRampA() external onlyOwner {
        swapStorage.stopRampA();
    }

    /**
     * @notice adjust the cap on LPTokens which can exist in the system 
     * @param newCap The new cap for LPTokens
     */
    function setLPCap(uint256 newCap) external onlyOwner {
        swapStorage.setLPCap(newCap);
    }
}
