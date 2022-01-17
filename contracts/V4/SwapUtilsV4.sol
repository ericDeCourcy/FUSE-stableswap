// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../contracts-v3_4/math/SafeMath.sol";
import "../contracts-v3_4/token/ERC20/SafeERC20.sol";
import "./AmplificationUtilsV4.sol";
import "./LPTokenV4.sol";
import "../MathUtils.sol";

/**
 * @title SwapUtils library
 * @notice A library to be used within Swap.sol. Contains functions responsible for custody and AMM functionalities.
 * @dev Contracts relying on this library must initialize SwapUtils.Swap struct then use this library
 * for SwapUtils.Swap struct. Note that this library contains both functions called by users and admins.
 * Admin functions should be protected within contracts using this library.
 */
library SwapUtilsV4 {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using MathUtils for uint256;

    /*** EVENTS ***/

    event TokenSwap(
        address indexed buyer,
        uint256 tokensSold,
        uint256 tokensBought,
        uint128 soldId,     //TODO - change this to indexed and uint8?
        uint128 boughtId
    );
    event TokenSwapExactOut(
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
    event NewLPCap(uint256 newCap);

    struct Swap {
        // variables around the ramp management of A,
        // the amplification coefficient * n * (n - 1)
        // see https://www.curve.fi/stableswap-paper.pdf for details
        uint256 initialA;
        uint256 futureA;
        uint256 initialATime;
        uint256 futureATime;
        // fee calculation
        uint256 swapFee;
        uint256 adminFee;
        uint256 lpCap;
        LPTokenV4 lpToken;
        // contract references for all tokens being pooled
        IERC20[] pooledTokens;
        // multipliers for each pooled token's precision to get to POOL_PRECISION_DECIMALS
        // for example, TBTC has 18 decimals, so the multiplier should be 1. WBTC
        // has 8, so the multiplier should be 10 ** 18 / 10 ** 8 => 10 ** 10
        uint256[] tokenPrecisionMultipliers;
        // the pool balance of each token, in the token's precision
        // the contract's actual token balance might differ
        uint256[] balances;
    }

    // Struct storing variables used in calculations in the
    // calculateWithdrawOneTokenDY function to avoid stack too deep errors
    struct CalculateWithdrawOneTokenDYInfo {
        uint256 d0;
        uint256 d1;
        uint256 newY;
        uint256 feePerToken;
        uint256 preciseA;
    }

    // Struct storing variables used in calculations in the
    // {add,remove}Liquidity functions to avoid stack too deep errors
    struct ManageLiquidityInfo {
        uint256 d0;
        uint256 d1;
        uint256 d2;
        uint256 preciseA;
        LPTokenV4 lpToken;
        uint256 totalSupply;
        uint256[] balances;
        uint256[] multipliers;
    }

    // the precision all pools tokens will be converted to
    uint8 public constant POOL_PRECISION_DECIMALS = 18;

    // the denominator used to calculate admin and LP fees. For example, an
    // LP fee might be something like tradeAmount.mul(fee).div(FEE_DENOMINATOR)
    uint256 private constant FEE_DENOMINATOR = 10**10;

    // Max swap fee is 1% or 100bps of each swap
    uint256 public constant MAX_SWAP_FEE = 10**8;

    // Max adminFee is 100% of the swapFee
    // adminFee does not add additional fee on top of swapFee
    // Instead it takes a certain % of the swapFee. Therefore it has no impact on the
    // users but only on the earnings of LPs
    uint256 public constant MAX_ADMIN_FEE = 10**10;

    // Constant value used as max loop limit
    uint256 private constant MAX_LOOP_LIMIT = 256;

    /*** VIEW & PURE FUNCTIONS ***/

   

    function _getAPrecise(Swap storage self) internal view returns (uint256) {
        return AmplificationUtilsV4._getAPrecise(self);
    }

    /**
     * @notice Calculate the dy, the amount of selected token that user receives and
     * the fee of withdrawing in one token
     * @param account the address that is withdrawing
     * @param tokenAmount the amount to withdraw in the pool's precision
     * @param tokenIndex which token will be withdrawn
     * @param self Swap struct to read from
     * @return the amount of token user will receive
     */
    function calculateWithdrawOneToken(
        Swap storage self,
        address account,
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view returns (uint256) {
        (uint256 availableTokenAmount, ) =
            _calculateWithdrawOneToken(
                self,
                account,
                tokenAmount,
                tokenIndex,
                self.lpToken.totalSupply()
            );
        return availableTokenAmount;
    }

    function _calculateWithdrawOneToken(
        Swap storage self,
        address account,
        uint256 tokenAmount,
        uint8 tokenIndex,
        uint256 totalSupply
    ) internal view returns (uint256, uint256) {
        uint256 dy;
        uint256 newY;
        uint256 currentY;

        (dy, newY, currentY) = calculateWithdrawOneTokenDY(
            self,
            tokenIndex,
            tokenAmount,
            totalSupply
        );

        // dy_0 (without fees)
        // dy, dy_0 - dy

        uint256 dySwapFee =
            currentY
                .sub(newY)
                .div(self.tokenPrecisionMultipliers[tokenIndex])
                .sub(dy);

        return (dy, dySwapFee);
    }

    /**
     * @notice Calculate the dy of withdrawing in one token
     * @param self Swap struct to read from
     * @param tokenIndex which token will be withdrawn
     * @param tokenAmount the amount to withdraw in the pools precision
     * @return the d and the new y after withdrawing one token
     */
    function calculateWithdrawOneTokenDY(
        Swap storage self,
        uint8 tokenIndex,
        uint256 tokenAmount,
        uint256 totalSupply
    )
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        // Get the current D, then solve the stableswap invariant
        // y_i for D - tokenAmount
        uint256[] memory xp = _xp(self);

        require(tokenIndex < xp.length, "Token index out of range");

        CalculateWithdrawOneTokenDYInfo memory v =
            CalculateWithdrawOneTokenDYInfo(0, 0, 0, 0, 0);
        v.preciseA = _getAPrecise(self);
        v.d0 = getD(xp, v.preciseA);
        v.d1 = v.d0.sub(tokenAmount.mul(v.d0).div(totalSupply));

        require(tokenAmount <= xp[tokenIndex], "Withdraw exceeds available");

        v.newY = getYD(v.preciseA, tokenIndex, xp, v.d1);

        uint256[] memory xpReduced = new uint256[](xp.length);

        v.feePerToken = _feePerToken(self.swapFee, xp.length);
        for (uint256 i = 0; i < xp.length; i++) {
            uint256 xpi = xp[i];
            // if i == tokenIndex, dxExpected = xp[i] * d1 / d0 - newY
            // else dxExpected = xp[i] - (xp[i] * d1 / d0)
            // xpReduced[i] -= dxExpected * fee / FEE_DENOMINATOR
            xpReduced[i] = xpi.sub(
                (
                    (i == tokenIndex)
                        ? xpi.mul(v.d1).div(v.d0).sub(v.newY)
                        : xpi.sub(xpi.mul(v.d1).div(v.d0))
                )
                    .mul(v.feePerToken)
                    .div(FEE_DENOMINATOR)
            );
        }

        uint256 dy =
            xpReduced[tokenIndex].sub(
                getYD(v.preciseA, tokenIndex, xpReduced, v.d1)
            );
        dy = dy.sub(1).div(self.tokenPrecisionMultipliers[tokenIndex]);

        return (dy, v.newY, xp[tokenIndex]);
    }

    /**
     * @notice Calculate the price of a token in the pool with given
     * precision-adjusted balances and a particular D.
     *
     * @dev This is accomplished via solving the invariant iteratively.
     * See the StableSwap paper and Curve.fi implementation for further details.
     *
     * x_1**2 + x1 * (sum' - (A*n**n - 1) * D / (A * n**n)) = D ** (n + 1) / (n ** (2 * n) * prod' * A)
     * x_1**2 + b*x_1 = c
     * x_1 = (x_1**2 + c) / (2*x_1 + b)
     *
     * @param a the amplification coefficient * n * (n - 1). See the StableSwap paper for details.
     * @param tokenIndex Index of token we are calculating for.
     * @param xp a precision-adjusted set of pool balances. Array should be
     * the same cardinality as the pool.
     * @param d the stableswap invariant
     * @return the price of the token, in the same precision as in xp
     */
    function getYD(
        uint256 a,
        uint8 tokenIndex,
        uint256[] memory xp,
        uint256 d
    ) internal pure returns (uint256) {
        uint256 numTokens = xp.length;
        require(tokenIndex < numTokens, "Token not found");

        uint256 c = d;
        uint256 s;
        uint256 nA = a.mul(numTokens);

        for (uint256 i = 0; i < numTokens; i++) {
            if (i != tokenIndex) {
                s = s.add(xp[i]);
                c = c.mul(d).div(xp[i].mul(numTokens));
                // If we were to protect the division loss we would have to keep the denominator separate
                // and divide at the end. However this leads to overflow with large numTokens or/and D.
                // c = c * D * D * D * ... overflow!
            }
        }
        c = c.mul(d).mul(AmplificationUtilsV4.A_PRECISION).div(
            nA.mul(numTokens)
        );

        uint256 b = s.add(d.mul(AmplificationUtilsV4.A_PRECISION).div(nA));
        uint256 yPrev;
        uint256 y = d;
        for (uint256 i = 0; i < MAX_LOOP_LIMIT; i++) {
            yPrev = y;
            y = y.mul(y).add(c).div(y.mul(2).add(b).sub(d));
            if (y.within1(yPrev)) {
                return y;
            }
        }
        revert("Approximation did not converge");
    }

    /**
     * @notice Get D, the StableSwap invariant, based on a set of balances and a particular A.
     * @param xp a precision-adjusted set of pool balances. Array should be the same cardinality
     * as the pool.
     * @param a the amplification coefficient * n * (n - 1) in A_PRECISION.
     * See the StableSwap paper for details
     * @return the invariant, at the precision of the pool
     */
    function getD(uint256[] memory xp, uint256 a)
        internal
        pure
        returns (uint256)
    {
        uint256 numTokens = xp.length;
        uint256 s;
        for (uint256 i = 0; i < numTokens; i++) {
            s = s.add(xp[i]);
        }
        if (s == 0) {
            return 0;
        }

        uint256 prevD;
        uint256 d = s;
        uint256 nA = a.mul(numTokens);

        for (uint256 i = 0; i < MAX_LOOP_LIMIT; i++) {
            uint256 dP = d;
            for (uint256 j = 0; j < numTokens; j++) {
                dP = dP.mul(d).div(xp[j].mul(numTokens));
                // If we were to protect the division loss we would have to keep the denominator separate
                // and divide at the end. However this leads to overflow with large numTokens or/and D.
                // dP = dP * D * D * D * ... overflow!
            }
            prevD = d;
            d = nA
                .mul(s)
                .div(AmplificationUtilsV4.A_PRECISION)
                .add(dP.mul(numTokens))
                .mul(d)
                .div(
                nA
                    .sub(AmplificationUtilsV4.A_PRECISION)
                    .mul(d)
                    .div(AmplificationUtilsV4.A_PRECISION)
                    .add(numTokens.add(1).mul(dP))
            );
            if (d.within1(prevD)) {
                return d;
            }
        }

        // Convergence should occur in 4 loops or less. If this is reached, there may be something wrong
        // with the pool. If this were to occur repeatedly, LPs should withdraw via `removeLiquidity()`
        // function which does not rely on D.
        revert("D does not converge");
    }

    /**
     * @notice Given a set of balances and precision multipliers, return the
     * precision-adjusted balances.
     *
     * @param balances an array of token balances, in their native precisions.
     * These should generally correspond with pooled tokens.
     *
     * @param precisionMultipliers an array of multipliers, corresponding to
     * the amounts in the balances array. When multiplied together they
     * should yield amounts at the pool's precision.
     *
     * @return an array of amounts "scaled" to the pool's precision
     */
    function _xp(
        uint256[] memory balances,
        uint256[] memory precisionMultipliers
    ) internal pure returns (uint256[] memory) {
        uint256 numTokens = balances.length;
        require(
            numTokens == precisionMultipliers.length,
            "Balances must match multipliers"
        );
        uint256[] memory xp = new uint256[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            xp[i] = balances[i].mul(precisionMultipliers[i]);
        }
        return xp;
    }

    /**
     * @notice Return the precision-adjusted balances of all tokens in the pool
     * @param self Swap struct to read from
     * @return the pool balances "scaled" to the pool's precision, allowing
     * them to be more easily compared.
     */
    function _xp(Swap storage self) internal view returns (uint256[] memory) {
        return _xp(self.balances, self.tokenPrecisionMultipliers);
    }

    /**
     * @notice Get the virtual price, to help calculate profit
     * @param self Swap struct to read from
     * @return the virtual price, scaled to precision of POOL_PRECISION_DECIMALS
     */
    function getVirtualPrice(Swap storage self)
        external
        view
        returns (uint256)
    {
        uint256 d = getD(_xp(self), _getAPrecise(self));
        LPTokenV4 lpToken = self.lpToken;
        uint256 supply = lpToken.totalSupply();
        if (supply > 0) {
            return d.mul(10**uint256(POOL_PRECISION_DECIMALS)).div(supply);
        }
        return 0;
    }

    /**
     * @notice Calculate the new balances of the tokens given the indexes of the token
     * that is swapped from (FROM) and the token that is swapped to (TO).
     * This function is used as a helper function to calculate how much TO token
     * the user should receive on swap.
     *
     * @param preciseA precise form of amplification coefficient
     * @param tokenIndexFrom index of FROM token
     * @param tokenIndexTo index of TO token
     * @param x the new total amount of FROM token
     * @param xp balances of the tokens in the pool
     * @return the amount of TO token that should remain in the pool
     */
    function getY(
        uint256 preciseA,
        uint8 tokenIndexFrom,       // index "x"
        uint8 tokenIndexTo,         // index "y"
        uint256 x,                  // amount of "x" after swap
        uint256[] memory xp         // balances before swap
    ) internal pure returns (uint256) {
        uint256 numTokens = xp.length;
        require(
            tokenIndexFrom != tokenIndexTo,
            "Can't compare token to itself"
        );
        require(
            tokenIndexFrom < numTokens && tokenIndexTo < numTokens,
            "Tokens must be in pool"
        );

        uint256 d = getD(xp, preciseA);
        uint256 c = d;
        uint256 s;
        uint256 nA = numTokens.mul(preciseA);

        uint256 _x;
        for (uint256 i = 0; i < numTokens; i++) {
            if (i == tokenIndexFrom) {
                _x = x;
            } else if (i != tokenIndexTo) {
                _x = xp[i];
            } else {
                continue;
            }
            s = s.add(_x);
            c = c.mul(d).div(_x.mul(numTokens));
            // If we were to protect the division loss we would have to keep the denominator separate
            // and divide at the end. However this leads to overflow with large numTokens or/and D.
            // c = c * D * D * D * ... overflow!
        }
        c = c.mul(d).mul(AmplificationUtilsV4.A_PRECISION).div(
            nA.mul(numTokens)
        );
        uint256 b = s.add(d.mul(AmplificationUtilsV4.A_PRECISION).div(nA));
        uint256 yPrev;
        uint256 y = d;

        // iterative approximation
        for (uint256 i = 0; i < MAX_LOOP_LIMIT; i++) {
            yPrev = y;
            y = y.mul(y).add(c).div(y.mul(2).add(b).sub(d));
            if (y.within1(yPrev)) {
                return y;
            }
        }
        revert("Approximation did not converge");
    }

    /**
     * @notice Externally calculates a swap between two tokens.
     * @param self Swap struct to read from
     * @param tokenIndexFrom the token to sell
     * @param tokenIndexTo the token to buy
     * @param dx the number of tokens to sell. If the token charges a fee on transfers,
     * use the amount that gets transferred after the fee.
     * @return dy the number of tokens the user will get
     */
    function calculateSwap(
        Swap storage self,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256 dy) {
        (dy, ) = _calculateSwap(
            self,
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            self.balances
        );
    }

    /**
     * @notice Internally calculates a swap between two tokens.
     *
     * @dev The caller is expected to transfer the actual amounts (dx and dy)
     * using the token contracts.
     *
     * @param self Swap struct to read from
     * @param tokenIndexFrom the token to sell
     * @param tokenIndexTo the token to buy
     * @param dx the number of tokens to sell. If the token charges a fee on transfers,
     * use the amount that gets transferred after the fee.
     * @return dy the number of tokens the user will get
     * @return dyFee the associated fee
     */
    function _calculateSwap(
        Swap storage self,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256[] memory balances
    ) internal view returns (uint256 dy, uint256 dyFee) {
        uint256[] memory multipliers = self.tokenPrecisionMultipliers;
        uint256[] memory xp = _xp(balances, multipliers);
        require(
            tokenIndexFrom < xp.length && tokenIndexTo < xp.length,
            "Token index out of range"
        );
        uint256 x = dx.mul(multipliers[tokenIndexFrom]).add(xp[tokenIndexFrom]);
        uint256 y =
            getY(_getAPrecise(self), tokenIndexFrom, tokenIndexTo, x, xp);
        dy = xp[tokenIndexTo].sub(y).sub(1);
        dyFee = dy.mul(self.swapFee).div(FEE_DENOMINATOR);
        dy = dy.sub(dyFee).div(multipliers[tokenIndexTo]); 
    }

    /**
     * @notice Calculates how many tokens will need to be sent in to recieve specified dy tokens out
     * @param self Swap struct to read from
     * @param tokenIndexFrom Index of token user will send in
     * @param tokenIndexTo Index of token user will recieve after swap
     * @param dy The number of tokens user wants to recieve
     * @return dx The number of tokens the user will need to send in, This includes the fee 
     */
    function calculateSwapExactOut(
        Swap storage self,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo, 
        uint256 dy
    ) external view returns (uint256 dx) {
        // calculate what dy would be with fee - this way we can match regular swap by calculating fee on output
        // UserOutput = Total * (100% - Fee)
        // Total = UserOutput / (100% - Fee)
        uint256 dyWithFee = dy
            .mul(FEE_DENOMINATOR)
            .div(FEE_DENOMINATOR - self.swapFee);   //no need for safeMath because we can be sure swapFee is lower than FEE_DENOMINATOR from it's setter
        uint256 dyFee = dyWithFee - dy;

        // calculate dx
        uint256[] memory balances = self.balances;
        uint256 dx = _calculateSwapExactOut(self, tokenIndexFrom, tokenIndexTo, dyWithFee, balances);   //pass in dyWithFee because we subtract the fee from output token, and we're computing input to arrive at output

        return dx;
    }



    /**
     * @return dx The number of tokens in to return dy tokens out
     */
    function _calculateSwapExactOut(
        Swap storage self,
        uint8 tokenIndexFrom,   // this is the index for token x
        uint8 tokenIndexTo,     // this is the index for token y
        uint256 dy,
        uint256[] memory balances
    ) internal view returns (uint256 dx) { 

        uint256[] memory multipliers = self.tokenPrecisionMultipliers;
        uint256[] memory xp = _xp(balances, multipliers);
        require(
            tokenIndexFrom < xp.length && tokenIndexTo < xp.length,
            "Token index out of range"
        );

        uint256 y = (xp[tokenIndexTo]).sub(dy.mul(multipliers[tokenIndexTo]));   //we want to calculate the number of tokens in the "to" pile
                                                                                    //which will be left after this swap. So we subtract
        uint256 x = 
            getY(_getAPrecise(self), tokenIndexTo, tokenIndexFrom, y, xp);    // we can use getY like in _calculateSwap, but we must swap "to" and "from" indices
                                                                                // this is cuz first index is the index where balance was changed,
                                                                                // second index is the index of the token balance we want to know (x)
     
        dx = (x.sub(xp[tokenIndexFrom]))
            .div(multipliers[tokenIndexFrom])
            .add(1);    // we add 1 to handle accounting error - make user pay slightly more lol sorrrry
                        // x will be higher than it's original balance, so we subtract original balance to get amt needed in
                        // fees are already accounted for when we pass in dy, so we don't need to double-count fees on the input
                        // we div by multipliers because getY returns a scaled balance
    }

    /**
     * @notice A simple method to calculate amount of each underlying
     * tokens that is returned upon burning given amount of
     * LP tokens
     *
     * @param account the address that is removing liquidity. required for withdraw fee calculation
     * @param amount the amount of LP tokens that would to be burned on
     * withdrawal
     * @return array of amounts of tokens user will receive
     */
    function calculateRemoveLiquidity(
        Swap storage self,
        address account,
        uint256 amount
    ) external view returns (uint256[] memory) {
        return
            _calculateRemoveLiquidity(
                self,
                self.balances,
                account,
                amount,
                self.lpToken.totalSupply()
            );
    }

    function _calculateRemoveLiquidity(
        Swap storage self,
        uint256[] memory balances,
        address account,
        uint256 amount,
        uint256 totalSupply
    ) internal view returns (uint256[] memory) {
        require(amount <= totalSupply, "Cannot exceed total supply");

        uint256[] memory amounts = new uint256[](balances.length);

        for (uint256 i = 0; i < balances.length; i++) {
            amounts[i] = balances[i].mul(amount).div(totalSupply);
        }
        return amounts;
    }

    /**
     * @notice A simple method to calculate prices from deposits or
     * withdrawals, excluding fees but including slippage. This is
     * helpful as an input into the various "min" parameters on calls
     * to fight front-running
     *
     * @dev This shouldn't be used outside frontends for user estimates.
     *
     * @param self Swap struct to read from
     * @param account address of the account depositing or withdrawing tokens
     * @param amounts an array of token amounts to deposit or withdrawal,
     * corresponding to pooledTokens. The amount should be in each
     * pooled token's native precision. If a token charges a fee on transfers,
     * use the amount that gets transferred after the fee.
     * @param deposit whether this is a deposit or a withdrawal
     * @return if deposit was true, total amount of lp token that will be minted and if
     * deposit was false, total amount of lp token that will be burned
     */
    function calculateTokenAmount(
        Swap storage self,
        address account,
        uint256[] calldata amounts,
        bool deposit
    ) external view returns (uint256) {
        uint256 a = _getAPrecise(self);
        uint256[] memory balances = self.balances;
        uint256[] memory multipliers = self.tokenPrecisionMultipliers;

        uint256 d0 = getD(_xp(balances, multipliers), a);
        for (uint256 i = 0; i < balances.length; i++) {
            if (deposit) {
                balances[i] = balances[i].add(amounts[i]);
            } else {
                balances[i] = balances[i].sub(
                    amounts[i],
                    "Cannot withdraw more than available"
                );
            }
        }
        uint256 d1 = getD(_xp(balances, multipliers), a);
        uint256 totalSupply = self.lpToken.totalSupply();

        if (deposit) {
            return d1.sub(d0).mul(totalSupply).div(d0);
        } else {
            return
                d0.sub(d1).mul(totalSupply).div(d0);
        }
    }

    /**
     * @notice return accumulated amount of admin fees of the token with given index
     * @param self Swap struct to read from
     * @param index Index of the pooled token
     * @return admin balance in the token's precision
     */
    function getAdminBalance(Swap storage self, uint256 index)
        external
        view
        returns (uint256)
    {
        require(index < self.pooledTokens.length, "Token index out of range");
        return
            self.pooledTokens[index].balanceOf(address(this)).sub(
                self.balances[index]
            );
    }

    /**
     * @notice internal helper function to calculate fee per token multiplier used in
     * swap fee calculations
     * @param swapFee swap fee for the tokens
     * @param numTokens number of tokens pooled
     */
    function _feePerToken(uint256 swapFee, uint256 numTokens)
        internal
        pure
        returns (uint256)
    {
        return swapFee.mul(numTokens).div(numTokens.sub(1).mul(4));
    }

    /*** STATE MODIFYING FUNCTIONS ***/

    /**
     * @notice swap two tokens in the pool
     * @param self Swap struct to read from and write to
     * @param tokenIndexFrom the token the user wants to sell
     * @param tokenIndexTo the token the user wants to buy
     * @param dx the amount of tokens the user wants to sell
     * @param minDy the min amount the user would like to receive, or revert.
     * @return amount of token user received on swap
     */
    function swap(
        Swap storage self,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy
    ) external returns (uint256) {
        {
            IERC20 tokenFrom = self.pooledTokens[tokenIndexFrom];
            require(
                dx <= tokenFrom.balanceOf(msg.sender),
                "Cannot swap more than you own"
            );
            // Transfer tokens first to see if a fee was charged on transfer
            uint256 beforeBalance = tokenFrom.balanceOf(address(this));
            tokenFrom.transferFrom(msg.sender, address(this), dx);

            // Use the actual transferred amount for AMM math
            dx = tokenFrom.balanceOf(address(this)).sub(beforeBalance);
        }

        uint256 dy;
        uint256 dyFee;
        uint256[] memory balances = self.balances;
        (dy, dyFee) = _calculateSwap(
            self,
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            balances
        );
        require(dy >= minDy, "Swap didn't result in min tokens");

        uint256 dyAdminFee =
            dyFee.mul(self.adminFee).div(FEE_DENOMINATOR).div(
                self.tokenPrecisionMultipliers[tokenIndexTo]
            );

        self.balances[tokenIndexFrom] = balances[tokenIndexFrom].add(dx);
        self.balances[tokenIndexTo] = balances[tokenIndexTo].sub(dy).sub(
            dyAdminFee
        );

        self.pooledTokens[tokenIndexTo].transfer(msg.sender, dy);

        emit TokenSwap(msg.sender, dx, dy, tokenIndexFrom, tokenIndexTo);

        return dy;
    }

    /**
     * @notice Conducts a swap which transfers up to maxDx in to trade for dy of token out
     * @param self Swap struct to read from
     * @param tokenIndexFrom Index of token user will send in for swap
     * @param tokenIndexTo Index of token user will recieve from swap
     * @param dy Number of tokens (indexTo) user wants to recieve
     * @param maxDx Maximum num of tokens (indexFrom) user is willing to pay
     * @return dx The number of tokens to pay in
     */
    function swapExactOut( 
        Swap storage self,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dy,
        uint256 maxDx
    ) external returns (uint256) {

        // calculate what dy would be with fee - this way we can match regular swap by calculating fee on output
        // UserOutput = Total * (100% - Fee)
        // Total = UserOutput / (100% - Fee)
        uint256 dyWithFee = dy
            .mul(FEE_DENOMINATOR)
            .div(FEE_DENOMINATOR - self.swapFee);   //no need for safeMath because we can be sure swapFee is lower than FEE_DENOMINATOR from it's setter
        uint256 dyFee = dyWithFee - dy;

        // calculate dx
        uint256[] memory balances = self.balances;
        uint256 dx = _calculateSwapExactOut(self, tokenIndexFrom, tokenIndexTo, dyWithFee, balances);   //pass in dyWithFee because we subtract the fee from output token, and we're computing input to arrive at output

        // Check that dx < maxDx
        require(dx <= maxDx, "Swap requires more than max tokens");

        // Transfer in tokens, checking that the desired amount was recieved
        // NOTE: this will only work for tokens which don't charge fees
        {
            IERC20 tokenFrom = self.pooledTokens[tokenIndexFrom];
            require(
                dx <= tokenFrom.balanceOf(msg.sender),
                "Cannot swap more than you own"
            );
            // Transfer tokens first to see if a fee was charged on transfer
            uint256 beforeBalance = tokenFrom.balanceOf(address(this));
            tokenFrom.transferFrom(msg.sender, address(this), dx);

            // set dx to the amount actually received, but make sure that it is at least as much as we need
            // we set dx to the actual received amount so we can update balances with it
            uint256 deltaBalance = tokenFrom.balanceOf(address(this)).sub(beforeBalance);
            require(dx >= deltaBalance, "Transferred too little token in");
            dx = deltaBalance;
        }

        // affect token balances
        uint256 dyAdminFee = dyFee.mul(self.adminFee).div(FEE_DENOMINATOR); //we don't need to scale by token multipliers like in swap()
        self.balances[tokenIndexFrom] = balances[tokenIndexFrom].add(dx);
        self.balances[tokenIndexTo] = balances[tokenIndexTo].sub(dy).sub(dyAdminFee);

        // transfer tokens out
        self.pooledTokens[tokenIndexTo].transfer(msg.sender, dy);

        // emit event
        emit TokenSwapExactOut(msg.sender, dx, dy, tokenIndexFrom, tokenIndexTo);

        // return dx
        return dx;
    }

    /**
     * @notice Add liquidity to the pool
     * @param self Swap struct to read from and write to
     * @param amounts the amounts of each token to add, in their native precision
     * @param minToMint the minimum LP tokens adding this amount of liquidity
     * should mint, otherwise revert. Handy for front-running mitigation
     * allowed addresses. If the pool is not in the guarded launch phase, this parameter will be ignored.
     * @return amount of LP token user received
     */
    function addLiquidity(
        Swap storage self,
        uint256[] memory amounts,
        uint256 minToMint
    ) external returns (uint256) {
        IERC20[] memory pooledTokens = self.pooledTokens;
        require(
            amounts.length == pooledTokens.length,
            "Amounts must match pooled tokens"
        );

        // current state
        ManageLiquidityInfo memory v =
            ManageLiquidityInfo(
                0,
                0,
                0,
                _getAPrecise(self),
                self.lpToken,
                0,
                self.balances,
                self.tokenPrecisionMultipliers
            );
        v.totalSupply = v.lpToken.totalSupply();

        if (v.totalSupply != 0) {
            v.d0 = getD(_xp(v.balances, v.multipliers), v.preciseA);
        }

        uint256[] memory newBalances = new uint256[](pooledTokens.length);

        for (uint256 i = 0; i < pooledTokens.length; i++) {
            require(
                v.totalSupply != 0 || amounts[i] > 0,
                "Must supply all tokens in pool"
            );

            // Transfer tokens first to see if a fee was charged on transfer
            if (amounts[i] != 0) {
                // This has been changed to a simple transfer, (rather than safeTransfer) assuming tokens don't charge fees. Check git history for more
                pooledTokens[i].transferFrom(msg.sender, address(this), amounts[i]);
            }

            newBalances[i] = v.balances[i].add(amounts[i]);
        }

        // invariant after change
        v.d1 = getD(_xp(newBalances, v.multipliers), v.preciseA);
        require(v.d1 > v.d0, "D should increase");

        // updated to reflect fees and calculate the user's LP tokens
        v.d2 = v.d1;
        uint256[] memory fees = new uint256[](pooledTokens.length);

        if (v.totalSupply != 0) {
            uint256 feePerToken =
                _feePerToken(self.swapFee, pooledTokens.length);
            for (uint256 i = 0; i < pooledTokens.length; i++) {
                uint256 idealBalance = v.d1.mul(v.balances[i]).div(v.d0);
                fees[i] = feePerToken
                    .mul(idealBalance.difference(newBalances[i]))
                    .div(FEE_DENOMINATOR);
                self.balances[i] = newBalances[i].sub(
                    fees[i].mul(self.adminFee).div(FEE_DENOMINATOR)
                );
                newBalances[i] = newBalances[i].sub(fees[i]);
            }
            v.d2 = getD(_xp(newBalances, v.multipliers), v.preciseA);
        } else {
            // the initial depositor doesn't pay fees
            self.balances = newBalances;
        }

        uint256 toMint;
        if (v.totalSupply == 0) {
            toMint = v.d1;
        } else {
            toMint = v.d2.sub(v.d0).mul(v.totalSupply).div(v.d0);
        }

        require(toMint >= minToMint, "Couldn't mint min requested");

        // mint the user's LP tokens
        v.lpToken.mint(msg.sender, toMint);

        // new in V3! Check that the cap has not been exceeded
        require(v.lpToken.totalSupply() <= self.lpCap, "LP token cap has been exceeded!");

        emit AddLiquidity(
            msg.sender,
            amounts,
            fees,
            v.d1,
            v.totalSupply.add(toMint)
        );

        return toMint;
    }

    /**
     * @notice Burn LP tokens to remove liquidity from the pool.
     * @dev Liquidity can always be removed, even when the pool is paused.
     * @param self Swap struct to read from and write to
     * @param amount the amount of LP tokens to burn
     * @param minAmounts the minimum amounts of each token in the pool
     * acceptable for this burn. Useful as a front-running mitigation
     * @return amounts of tokens the user received
     */
    function removeLiquidity(
        Swap storage self,
        uint256 amount,
        uint256[] calldata minAmounts
    ) external returns (uint256[] memory) {
        LPTokenV4 lpToken = self.lpToken;
        IERC20[] memory pooledTokens = self.pooledTokens;
        require(amount <= lpToken.balanceOf(msg.sender), ">LP.balanceOf");
        require(
            minAmounts.length == pooledTokens.length,
            "minAmounts must match poolTokens"
        );

        uint256[] memory balances = self.balances;
        uint256 totalSupply = lpToken.totalSupply();

        uint256[] memory amounts =
            _calculateRemoveLiquidity(
                self,
                balances,
                msg.sender,
                amount,
                totalSupply
            );

        for (uint256 i = 0; i < amounts.length; i++) {
            require(amounts[i] >= minAmounts[i], "amounts[i] < minAmounts[i]");
            self.balances[i] = balances[i].sub(amounts[i]);
            pooledTokens[i].transfer(msg.sender, amounts[i]);
        }

        lpToken.burnFrom(msg.sender, amount);

        emit RemoveLiquidity(msg.sender, amounts, totalSupply.sub(amount));

        return amounts;
    }

    /**
     * @notice Remove liquidity from the pool all in one token.
     * @param self Swap struct to read from and write to
     * @param tokenAmount the amount of the lp tokens to burn
     * @param tokenIndex the index of the token you want to receive
     * @param minAmount the minimum amount to withdraw, otherwise revert
     * @return amount chosen token that user received
     */
    function removeLiquidityOneToken(
        Swap storage self,
        uint256 tokenAmount,
        uint8 tokenIndex,
        uint256 minAmount
    ) external returns (uint256) {
        LPTokenV4 lpToken = self.lpToken;
        IERC20[] memory pooledTokens = self.pooledTokens;

        require(tokenAmount <= lpToken.balanceOf(msg.sender), ">LP.balanceOf");
        require(tokenIndex < pooledTokens.length, "Token not found");

        uint256 totalSupply = lpToken.totalSupply();

        (uint256 dy, uint256 dyFee) =
            _calculateWithdrawOneToken(
                self,
                msg.sender,
                tokenAmount,
                tokenIndex,
                totalSupply
            );

        require(dy >= minAmount, "dy < minAmount");

        self.balances[tokenIndex] = self.balances[tokenIndex].sub(
            dy.add(dyFee.mul(self.adminFee).div(FEE_DENOMINATOR))
        );
        lpToken.burnFrom(msg.sender, tokenAmount);
        pooledTokens[tokenIndex].transfer(msg.sender, dy);

        emit RemoveLiquidityOne(
            msg.sender,
            tokenAmount,
            totalSupply,
            tokenIndex,
            dy
        );

        return dy;
    }

    /**
     * @notice Remove liquidity from the pool, weighted differently than the
     * pool's current balances.
     *
     * @param self Swap struct to read from and write to
     * @param amounts how much of each token to withdraw
     * @param maxBurnAmount the max LP token provider is willing to pay to
     * remove liquidity. Useful as a front-running mitigation.
     * @return actual amount of LP tokens burned in the withdrawal
     */
    function removeLiquidityImbalance(
        Swap storage self,
        uint256[] memory amounts,
        uint256 maxBurnAmount
    ) public returns (uint256) {
        ManageLiquidityInfo memory v =
            ManageLiquidityInfo(
                0,
                0,
                0,
                _getAPrecise(self),
                self.lpToken,
                0,
                self.balances,
                self.tokenPrecisionMultipliers
            );
        v.totalSupply = v.lpToken.totalSupply();

        IERC20[] memory pooledTokens = self.pooledTokens;

        require(
            amounts.length == pooledTokens.length,
            "Amounts should match pool tokens"
        );

        require(
            maxBurnAmount <= v.lpToken.balanceOf(msg.sender) &&
                maxBurnAmount != 0,
            ">LP.balanceOf"
        );

        uint256 feePerToken = _feePerToken(self.swapFee, pooledTokens.length);
        uint256[] memory fees = new uint256[](pooledTokens.length);
        {
            uint256[] memory balances1 = new uint256[](pooledTokens.length);
            v.d0 = getD(_xp(v.balances, v.multipliers), v.preciseA);
            for (uint256 i = 0; i < pooledTokens.length; i++) {
                balances1[i] = v.balances[i].sub(
                    amounts[i],
                    "Cannot withdraw more than available"
                );
            }
            v.d1 = getD(_xp(balances1, v.multipliers), v.preciseA);

            for (uint256 i = 0; i < pooledTokens.length; i++) {
                uint256 idealBalance = v.d1.mul(v.balances[i]).div(v.d0);
                uint256 difference = idealBalance.difference(balances1[i]);
                fees[i] = feePerToken.mul(difference).div(FEE_DENOMINATOR);
                self.balances[i] = balances1[i].sub(
                    fees[i].mul(self.adminFee).div(FEE_DENOMINATOR)
                );
                balances1[i] = balances1[i].sub(fees[i]);
            }

            v.d2 = getD(_xp(balances1, v.multipliers), v.preciseA);
        }
        uint256 tokenAmount = v.d0.sub(v.d2).mul(v.totalSupply).div(v.d0);
        require(tokenAmount != 0, "Burnt amount cannot be zero");
        tokenAmount = tokenAmount.add(1);

        require(tokenAmount <= maxBurnAmount, "tokenAmount > maxBurnAmount");

        v.lpToken.burnFrom(msg.sender, tokenAmount);

        for (uint256 i = 0; i < pooledTokens.length; i++) {
            pooledTokens[i].transfer(msg.sender, amounts[i]);
        }

        emit RemoveLiquidityImbalance(
            msg.sender,
            amounts,
            fees,
            v.d1,
            v.totalSupply.sub(tokenAmount)
        );

        return tokenAmount;
    }

    /**
     * @notice withdraw all admin fees to a given address
     * @param self Swap struct to withdraw fees from
     * @param to Address to send the fees to
     */
    function withdrawAdminFees(Swap storage self, address to) external {
        IERC20[] memory pooledTokens = self.pooledTokens;
        for (uint256 i = 0; i < pooledTokens.length; i++) {
            IERC20 token = pooledTokens[i];
            uint256 balance =
                token.balanceOf(address(this)).sub(self.balances[i]);
            if (balance != 0) {
                token.transfer(to, balance);
            }
        }
    }

    /**
     * @notice Sets the admin fee
     * @dev adminFee cannot be higher than 100% of the swap fee
     * @param self Swap struct to update
     * @param newAdminFee new admin fee to be applied on future transactions
     */
    function setAdminFee(Swap storage self, uint256 newAdminFee) external {
        require(newAdminFee <= MAX_ADMIN_FEE, "Fee is too high");
        self.adminFee = newAdminFee;

        emit NewAdminFee(newAdminFee);
    }

    /**
     * @notice update the swap fee
     * @dev fee cannot be higher than 1% of each swap
     * @param self Swap struct to update
     * @param newSwapFee new swap fee to be applied on future transactions
     */
    function setSwapFee(Swap storage self, uint256 newSwapFee) external {   
        require(newSwapFee <= MAX_SWAP_FEE, "Fee is too high");
        self.swapFee = newSwapFee;

        emit NewSwapFee(newSwapFee);
    }

    /**
     * @notice Updates the cap on LP token supply
     * @param self Swap struct to update
     * @param newCap new LPToken supply cap
     */
    function setLPCap(Swap storage self, uint256 newCap) external
    {
        require(self.lpToken.totalSupply() <= newCap, "Cannot set cap lower than current LP supply");   //cap must be greater than or equal to current supply
        self.lpCap = newCap;

        emit NewLPCap(newCap);

    }
}
