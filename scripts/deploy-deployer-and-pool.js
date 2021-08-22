async function main() {
  
  // TODO: figure out how to programmatically await the success of a transaction
  // OR: figure out how to broadcast a bunch of tx's with the correct nonce order
  const timeout = 25000;
  
  const owner = await ethers.getSigners();
  
  ///// Deploy the template for SwapFlashLoanV1 and LPTokenV1 //////

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

  /////////////////////////////////////////////////////////////////////
  

  /////// Deploy 3 fake tokens ////////////////////////////////////////
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
  //////////////////////////////////////////////////////////////////////


  /////// Deploy a deployer  ///////////////////////////////////////////
  // deploy deployer
  const SwapDeployerV1 = await ethers.getContractFactory("SwapDeployerV1");
  const swapdeployerv1 = await SwapDeployerV1.deploy();
  console.log("SwapDeployerV1 deployed to:", swapdeployerv1.address);

  await new Promise(r => setTimeout(r, timeout));
  //////////////////////////////////////////////////////////////////////// 
 



  //////// deploy a pool by calling into deployer contract //////////////////////
  const INIT = await swapdeployerv1.deploy(swapflashloan.address,[fakedai.address,fakeusdc.address,fakeusdt.address],[18,6,6],"FSS-FAKE-DAI-USDC-USDT-V1","LP-FAKE-USD-V1",100,100,100,0,lptoken.address);
  console.log("pool initialized in hash:", INIT);

  await new Promise(r => setTimeout(r, timeout));
  ////////////////////////////////////////////////////////////////////////


  // TODO: understand promises and ethers enough to programmatically combine this script with the test-deployed-pool.js script
    // we need to await the return value of the deploy transaction to get the address of the new instance of the swap pool and the LPToken
  
  
  console.log("You will need to edit, then run the interaction script (test-deployed-pool.js)");
  console.log("You'll need to put some values into the script for it to run correctly");
  console.log("Most of these values can be provided here, but you'll need to look for the logs in the deploy transaction to get the swap contract instance's deployed address");

  console.log("Deployment transaction (get the deployed address here):", INIT.hash);
  console.log("Look at this transaction and determine what other contracts were deployed. The contract which isn't present in the event is the new LPToken instance");

  console.log("You can pretty much copy-paste this into the next script. Make sure to add the proper addresses!:")
  console.log(" ");
  console.log("const SwapUtilsAddress = \"", swaputils.address, "\";");
  console.log("const AmpUtilsAddress = \"", amplificationUtils.address, "\";");
  console.log("const SwapFlashLoanAddress = /* deployed swap contract address */;");
  console.log("const LPTokenAddress = /* deployed LP token address */;");
  console.log("const FakeDAIAddress = \"", fakedai.address,"\"");
  console.log("const FakeUSDCAddress = \"", fakeusdc.address,"\"");
  console.log("const FakeUSDTAddress\"", fakeusdt.address, "\"");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
