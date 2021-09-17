// This contract exists to facilitate easy joins for the "fake" pool.
// note that addresses are hard-coded, so this contract will only work when the addresses
// that are present here are also correct
// These addresses are for Fuse network

import "../interfaces/ISwapV2.sol";
import "../interfaces/IMockMintableERC20.sol";

contract FakeJoiner {

    /// DEPLOYMENT-SPECIFIC ADDRESSES /////
    address constant LPTokenAddress = 0x410a69Cdb3320594019Ef14A7C3Fb4Abaf6e962e;
    address constant fakeDaiAddress = 0xa277bc1c1612Bb327D79746475aF29F7a93e8E64;
    address constant fakeUSDCAddress = 0x88c784FACBE88A20601A32Bd98d9Da8d59d08F92;
    address constant fakeUSDTAddress = 0xa479351d97e997EbCb453692Ef16Ce06730bEBF4;
    address constant swapPoolAddress = 0xeADfEa5f18c1E1D5030dd352f293d78865a264a2;
    /////////////////////////////////////////


    // enforces that each account can use this contract once
    mapping(address => bool) alreadyJoined;

    // so that we can set everything up once
    bool setupDone;

    // anti-spam timer
    uint256 timeOfLastUse;
    uint256 constant delay = 900; //900 seconds is 15 minutes

    fallback() external payable 
    {
        // check if this user has already already joined
        require(!alreadyJoined[msg.sender], "User can only use this contract once!");
        require(block.timestamp - timeOfLastUse >= delay, "This contract can only be used once every 15 minutes. Try again soon");

        // set user as already joined
        alreadyJoined[msg.sender] = true;

        // check if already set up. If not...
        if(!setupDone)
        {
            // mint 1 million of each of these tokens
            IMockMintableERC20(fakeDaiAddress).mintAmount(1000000e18);
            IMockMintableERC20(fakeUSDCAddress).mintAmount(1000000e6);
            IMockMintableERC20(fakeUSDTAddress).mintAmount(1000000e6);

            // call approve for each token...
            IMockMintableERC20(fakeDaiAddress).approve(swapPoolAddress,  1000000e18);    // approve 1 million fake DAI
            IMockMintableERC20(fakeUSDCAddress).approve(swapPoolAddress, 1000000e6);     // approve 1 million fake USDC
            IMockMintableERC20(fakeUSDTAddress).approve(swapPoolAddress, 1000000e6);     // approve 1 million fake USDT

            // then set setupDone to true
            setupDone = true;
        }

        // conduct a deposit into the swap pool of [100,100,100] DAI,USDC,USDT
        // params: amounts[], minToMint, deadline
        uint256[] storage amountsIn;
        amountsIn.push(100e18);
        amountsIn.push(100e6);
        amountsIn.push(100e6);
        uint256[] memory amountsInReally = amountsIn;

        uint256 minted = ISwapV2(swapPoolAddress).addLiquidity(amountsInReally, 1, block.timestamp+1);

        // transfer minted tokens to the user
        IMockMintableERC20(LPTokenAddress).transfer(msg.sender, minted);
    }

    // tells you the timestamp of the next time the contract will be usable
    function getNextUsableTimestamp() public view returns(uint256)
    {
        return timeOfLastUse + delay;
    }

    // tells you whether this contract is currently usable (the anti-spam timer has run out)
    function isCurrentlyUsable() public view returns(bool)
    {
        return (block.timestamp - timeOfLastUse >= delay);
    }
}