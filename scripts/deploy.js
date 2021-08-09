async function main() {
  
  const owner = await ethers.getSigners();
  
  // deploy SwapUtilsV1
  const SwapUtils = await ethers.getContractFactory("SwapUtilsV1");
  const swaputils = await SwapUtils.deploy();
  console.log("SwapUtilsV1 deployed to:", swaputils.address);
  
  // deploy AmplificationUtils
  const AmplificationUtils = await ethers.getContractFactory("AmplificationUtilsV1");
  const amplificationUtils = await AmplificationUtils.deploy();
  console.log("AmplificationUtilsV1 deployed to:", amplificationUtils.address);

  
  //deploy SwapFlashLoanV1
  const SwapFlashLoan = await ethers.getContractFactory("SwapFlashLoanV1", {libraries: {AmplificationUtilsV1: amplificationUtils.address, SwapUtilsV1: swaputils.address},});
  const swapflashloan = await SwapFlashLoan.deploy();
  console.log("swapflashloan deployed to:", swapflashloan.address);
  
  
  // deploy LPTokenV1
  const LPToken = await ethers.getContractFactory("LPTokenV1");
  const lptoken = await LPToken.deploy();
  console.log("LPTokenV1 deployed to:", lptoken.address);
  
  // deploy 3 fake tokens
  // deploy fake DAI
  const FakeDAI = await ethers.getContractFactory("MockDAIMintable");
  const fakedai = await FakeDAI.deploy();
  console.log("MockDAIMintable deployed to:", fakedai.address);

  // deploy fake USDC
  const FakeUSDC = await ethers.getContractFactory("MockUSDCMintable");
  const fakeusdc = await FakeUSDC.deploy();
  console.log("MockUSDCMintable deployed to:", fakeusdc.address);

  // deploy fake USDT
  const FakeUSDT = await ethers.getContractFactory("MockUSDTMintable");
  const fakeusdt = await FakeUSDT.deploy();
  console.log("MockUSDTMintable deployed to:", fakeusdt.address);
  
  //deploy SwapDeployerV1
  const SwapDeployer = await ethers.getContractFactory("SwapDeployerV1");
  const swapdeployer = await SwapDeployer.deploy();
  console.log("swapdeployer deployed to:", swapdeployer.address);
  
  // call swapdeployer to deploy an instance of swapflashloan
  // we must be careful to call "swapdeployer" vs "SwapDeployer" as calling .deploy on SwapDeployer will deploy a whole new instance of the contract
  const pooladdress = await swapdeployer.deploy(swapflashloan.address,[fakedai.address,fakeusdc.address,fakeusdt.address],[18,6,6],"FSS-FAKE-DAI-USDC-USDT-V1","LP-FAKE-V1",100,1000,1000,1,lptoken.address);
  console.log("pool deployed in hash:", pooladdress.hash);

  
  // deploy instance of swap
  /*
  await deployer.deploy('0x51b5e1ea7CF86F2bd49D65CD530b36FCe204C9d6',['0xfe0e877f64EcDDC1FEAD698842931C9f5a279bd8', '0x6A6cB2fB37970e20384B2f4e2390D31cB6bdA9b2', '0x31474310e0e37dA2483bE1F419124fcCdE931f5F'],[18,6,6],"Test-Fake-DAI-USDC-USDT","TEST-DAI-USDC-USDT", 100, 10000000,10000000,10000000, '0x1A8090F1F861aD4D0f71D7C48767e9a8351DcdC0')
  */
  
  
  
  // mint preset, then approve for transfer to pool contract
  await fakedai.mintPreset();
  await fakeusdc.mintPreset();
  await fakeusdt.mintPreset();  
  
  // TODO: rename pooladdress.to to something like pool so we dont have confusion
  await fakedai.approve("0x220Cdb4b51E03A1919668684571DE5D0236fDd6A","10000000000000000000000"); //10k dai
  await fakeusdc.approve("0x220Cdb4b51E03A1919668684571DE5D0236fDd6A",10000000000);  //10k USDC
  await fakeusdt.approve("0x220Cdb4b51E03A1919668684571DE5D0236fDd6A",10000000000); //10K USDT
  
    // attach poolInstance to an instance of a swap pool
  const poolInstance = await SwapFlashLoan.attach("0x220Cdb4b51E03A1919668684571DE5D0236fDd6A");

   
  // add liquidity of 1 of each token
  const liquidityAddedReturn = await poolInstance.addLiquidity(["1000000000000000000",1000000,1000000],1,1659586065);
  
  console.log("liquidityAddedReturn is: ", liquidityAddedReturn);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
