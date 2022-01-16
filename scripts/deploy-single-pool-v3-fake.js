// TODO: make sure that everything here says "V3" instead of "V1" or "V2"

async function main() {

  const timeout = 25000; // can set to 5 for local testing

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


  // deploy 3 fake tokens
  // deploy fake DAI
  const FakeDAI = await ethers.getContractFactory("MockDAIMintable");
  const fakedai = await FakeDAI.deploy();
  console.log("MockDAIMintable deployed to:", fakedai.address);

  await new Promise(r => setTimeout(r, timeout));

  // deploy fake USDC
  const FakeUSDC = await ethers.getContractFactory("MockUSDCMintable");
  const fakeusdc = await FakeUSDC.deploy();
  console.log("MockUSDCMintable deployed to:", fakeusdc.address);

  await new Promise(r => setTimeout(r, timeout));

  // deploy fake USDT
  const FakeUSDT = await ethers.getContractFactory("MockUSDTMintable");
  const fakeusdt = await FakeUSDT.deploy();
  console.log("MockUSDTMintable deployed to:", fakeusdt.address);

  await new Promise(r => setTimeout(r, timeout));

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
  const INIT = await swapflashloan.initialize([fakedai.address, fakeusdc.address, fakeusdt.address], [18, 6, 6], "FSS-FAKE-DAI-USDC-USDT-V3", "LP-FAKE-USD-V3", 100, 100, 100, lptoken.address, lprewards.address);
  console.log("pool initialized in hash:", INIT);

  await new Promise(r => setTimeout(r, timeout));

  // mint preset amounts of each token
  // fake dai...
  const fakeDaiMint = await fakedai.mintAmount("100000000000000000000000000");
  console.log("minting fake dai");

  await new Promise(r => setTimeout(r, timeout));

  // fake usdc...
  const fakeUsdcMint = await fakeusdc.mintAmount("100000000000000");
  console.log("minting fake usdc");

  await new Promise(r => setTimeout(r, timeout));

  // fake usdt...
  const fakeUsdtMint = await fakeusdt.mintAmount("100000000000000");
  console.log("minting fake usdt");

  await new Promise(r => setTimeout(r, timeout));

  // approve tokens for pool
  // fake dai...
  const fakeDaiApprove = await fakedai.approve(swapflashloan.address, "10000000000000000000000"); //10k dai
  console.log("approving fake dai");

  await new Promise(r => setTimeout(r, timeout));

  // fake usdc...
  const fakeUsdcApprove = await fakeusdc.approve(swapflashloan.address, 10000000000);  //10k USDC
  console.log("approving fake usdc");

  await new Promise(r => setTimeout(r, timeout));

  // fake usdt...
  const fakeUsdtApprove = await fakeusdt.approve(swapflashloan.address, 10000000000); //10K USDT
  console.log("approving fake usdt");

  await new Promise(r => setTimeout(r, timeout));

  // add liquidity of 10 of each token
  const liquidityAddedReturn = await swapflashloan.addLiquidity(["10000000000000000000", 10000000, 10000000], 1, 1659586065);
  console.log("calling addLiquidity");

  await new Promise(r => setTimeout(r, timeout));

  // add liquidity of 1,1,10
  await swapflashloan.addLiquidity(["1000000000000000000", "1000000", "10000000"], 1, 1659586065);
  console.log("calling addliquidity imblanced");

  await new Promise(r => setTimeout(r, timeout));

  // deploy rewards token
  const RewardToken = await ethers.getContractFactory("MockRewardTokenMintable");
  const rewardtoken = await RewardToken.deploy();
  console.log("deploying fake reward token");

  await new Promise(r => setTimeout(r, timeout));

  // mint preset on rewards token
  await rewardtoken.mintPreset();
  console.log("minting preset on fake reward token");

  await new Promise(r => setTimeout(r, timeout));

  // We need to approve the LP token to be transferred before removing liquidity
  /* const THISLPTOKEN = await ethers.getContractFactory("LPTokenV1");
   const thisLpToken = await THISLPTOKEN.attach(INIT);
   thisLpToken.approve(swapflashloan.address, 99999999999999999999999999);
   console.log("approving lp tokens for burn");
   
   await new Promise(r => setTimeout(r, timeout));
   
   // remove liquidity regular
   await swapflashloan.removeLiquidity("1000000000000000000", [1,1,1], 1659586065);
   console.log("calling removeLiquidity");
   
   await new Promise(r => setTimeout(r, timeout));
   
   // remove liquidity one token
   await swapflashloan.removeLiquidityOneToken(100,1,1,1659586065);
   console.log("calling removeLiquidityOneToken");
   
   await new Promise(r => setTimeout(r, timeout));
   
   // remove liquidity imbalanced'ly
   // [1,2,3] are the proportions
   // we say max burn amount is 10 lp tokens so 10e18
   await swapflashloan.removeLiquidityImbalance(["1000000000000000000",2000000,3000000],"10000000000000000000",1659586065);
   console.log("calling removeLiquidityImbalance");
   
   await new Promise(r => setTimeout(r, timeout)); */

  // swap 5 dai for USDC
  const swapAction = await swapflashloan.swap(0, 1, "5000000000000000000", 1, 1659586065);
  console.log("calling swap");
  console.log("");
  console.log("You will need to manually call approve and then remove liquidity.");
  console.log("call `approve` in the LP token contract. You will need to `approve` the Swap contract to transfer your tokens. Both of these contracts are deployed as proxies by this transaction:", INIT.hash);
  console.log(" ");
  console.log("const SwapFlashLoan = await ethers.getContractFactory(\"SwapFlashLoanV3\", {libraries: {AmplificationUtilsV3: <addr>, SwapUtilsV3: <addr>},});");
  console.log("const swap = await SwapFlashLoan.attach(\"<poolAddress>\");");
  console.log(" ");
  console.log("const LPTOKEN = await ethers.getContractFactory(\"ERC20\");");
  console.log("const lptoken = await LPTOKEN.attach(<lp token addr>);");
  console.log(" ");
  console.log("const approveAction = await lptoken.approve(\"<poolAddress>\", \"999999999999999999999999999\");");
  console.log(" ");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
