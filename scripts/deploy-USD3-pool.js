async function main() {

    const timeout = 25000;
  
    const owner = await ethers.getSigners();
  
    console.log("starting deploy script...");
  
    // deploy SwapUtilsV3
    const SwapUtils = await ethers.getContractFactory("SwapUtilsV3");
    const swaputils = await SwapUtils.deploy();
    console.log("SwapUtilsV3 deployed to:", swaputils.address);
  
    await new Promise(r => setTimeout(r, timeout));
  
    // deploy AmplificationUtils
    const AmplificationUtils = await ethers.getContractFactory("AmplificationUtilsV3");
    const amplificationUtils = await AmplificationUtils.deploy();
    console.log("AmplificationUtilsV3 deployed to:", amplificationUtils.address);
  
    await new Promise(r => setTimeout(r, timeout));
  
    //deploy SwapFlashLoanV3
    const SwapFlashLoan = await ethers.getContractFactory("SwapFlashLoanV3", { libraries: { AmplificationUtilsV3: amplificationUtils.address, SwapUtilsV3: swaputils.address }, });
    const swapflashloan = await SwapFlashLoan.deploy();
    console.log("swapflashloan deployed to:", swapflashloan.address);
  
    await new Promise(r => setTimeout(r, timeout));
  
    // deploy LPTokenV3
    const LPToken = await ethers.getContractFactory("LPTokenV3");
    const lptoken = await LPToken.deploy();
    console.log("LPTokenV3 deployed to:", lptoken.address);
  
    await new Promise(r => setTimeout(r, timeout));
  
    // deploy LPRewardsV3
    const LPRewards = await ethers.getContractFactory("LPRewardsV3");
    const lprewards = await LPRewards.deploy();
    console.log("LPRewardsV3 deployed to:", lprewards.address);
  
    await new Promise(r => setTimeout(r, timeout));
  
    // declare addresses of diff tokens
    FUSD_Address = "0x249BE57637D8B013Ad64785404b24aeBaE9B098B";
    ONEFUSE_Address = "0x8A5eE71Cd4Db6b7ffdCE37313006e48FaD6ADdB0";
    BUSD_Address = "0x6a5F6A8121592BeCd6747a38d67451B310F7f156";
    USDT_Address = "0xFaDbBF8Ce7D5b7041bE672561bbA99f79c532e10";

    // initialize pool
    /*
          IERC20[] memory _pooledTokens,
          uint8[] memory decimals,
          string memory lpTokenName,
          string memory lpTokenSymbol,
          uint256 _a,
          uint256 _fee,
          uint256 _adminFee,
          address lpTokenTargetAddress,
          address lpRewardsTargetAddress
    */
    // TODO: make sure A is scaled correctly. We want it to be 1000
    const INIT = await swapflashloan.initialize([FUSD_Address, ONEFUSE_Address, BUSD_Address, USDT_Address], [18, 18, 18, 6], "FSS-USD3-LP", "FSS-USD3-LP", 1000, 5000000, 100, lptoken.address, lprewards.address);
    console.log("pool initialized in hash:", INIT);
  
    await new Promise(r => setTimeout(r, timeout));
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
  