async function main() {
  
  const timeout = 25000;
  
  const owner = await ethers.getSigners();
  
  // deploy SwapUtilsV1
  const SwapUtils = await ethers.getContractFactory("SwapUtilsV1");
  const swaputils = await SwapUtils.deploy();
  console.log("SwapUtilsV1 deployed to:", swaputils.address);
  
  await new Promise(r => setTimeout(r, timeout));
  
  // deploy AmplificationUtils
  const AmplificationUtils = await ethers.getContractFactory("AmplificationUtilsV1");
  const amplificationUtils = await AmplificationUtils.deploy();
  console.log("AmplificationUtilsV1 deployed to:", amplificationUtils.address);

  await new Promise(r => setTimeout(r, timeout));
  
  //deploy SwapFlashLoanV1
  const SwapFlashLoan = await ethers.getContractFactory("SwapFlashLoanV1", {libraries: {AmplificationUtilsV1: amplificationUtils.address, SwapUtilsV1: swaputils.address},});
  const swapflashloan = await SwapFlashLoan.deploy();
  console.log("swapflashloan deployed to:", swapflashloan.address);

  await new Promise(r => setTimeout(r, timeout));  
  
  // deploy LPTokenV1
  const LPToken = await ethers.getContractFactory("LPTokenV1");
  const lptoken = await LPToken.deploy();
  console.log("LPTokenV1 deployed to:", lptoken.address);

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
  const INIT = await swapflashloan.initialize([fakedai.address,fakeusdc.address,fakeusdt.address],[18,6,6],"FSS-FAKE-DAI-USDC-USDT-V1","LP-FAKE-USD-V1",100,100,100,0,lptoken.address);
  console.log("pool initialized in hash:", INIT);

  await new Promise(r => setTimeout(r, timeout));
  
  // mint preset, then approve for transfer to pool contract
  const fakeDaiMint = await fakedai.mintPreset();

  await new Promise(r => setTimeout(r, timeout));

  const fakeUsdcMint = await fakeusdc.mintPreset();

  await new Promise(r => setTimeout(r, timeout));

  const fakeUsdtMint = await fakeusdt.mintPreset();  

  await new Promise(r => setTimeout(r, timeout));
  
  // approve tokens for pool
  const fakeDaiApprove = await fakedai.approve(swapflashloan.address,"10000000000000000000000"); //10k dai

  await new Promise(r => setTimeout(r, timeout));

  const fakeUsdcApprove = await fakeusdc.approve(swapflashloan.address,10000000000);  //10k USDC

  await new Promise(r => setTimeout(r, timeout));

  const fakeUsdtApprove = await fakeusdt.approve(swapflashloan.address,10000000000); //10K USDT
  
  await new Promise(r => setTimeout(r, timeout));
 
  // add liquidity of 100 of each token
  const liquidityAddedReturn = await swapflashloan.addLiquidity(["100000000000000000000",100000000,100000000],1,1659586065);
  console.log("calling addLiquidity");

  await new Promise(r => setTimeout(r, timeout));
  
  // add liquidity of 10,10,100
  await swapflashloan.addLiquidity(["10000000000000000000","10000000","100000000"],1,1659586065);
  console.log("calling addliquidity imblanced");
  
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
  const swapAction = await swapflashloan.swap(0,1,"5000000000000000000",1,1659586065);
  console.log("calling swap");
  
  console.log("You will need to manually call approve and then remove liquidity");
  console.log("call approve in the contract which is the return value in this transaction:", INIT.hash);
  console.log("approve the swap contract to transfer your LP tokens. Swap contract address: ", swapflashloan.address);
  console.log("SwapUtils: ", swaputils.address);
  console.log("AmpUtils: ", amplificationUtils.address);
  console.log(" ");
  console.log("const SwapFlashLoan = await ethers.getContractFactory(\"SwapFlashLoanV1\", {libraries: {AmplificationUtilsV1: <addr>, SwapUtilsV1: <addr>},});");
  console.log("const swap = await SwapFlashLoan.attach(\"",swapflashloan.address,"\"");
  console.log(" ");
  console.log("const LPTOKEN = await ethers.getContractFactory(\"ERC20\")");
  console.log("const lptoken = LPTOKEN.attach(<lp token addr>)");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
