const { expect } = require("chai");

describe("SwapV1-test", function () {
  this.enableTimeouts(false);
  
  // Token approvals
  it("Fake Dai should allow us to approve tokens for the SwapV1 contract", async function () {
    const [owner] = await ethers.getSigners();
    
    console.log("Here is the owner:", owner.address);

    // assign fake dai to the contract address
    const FakeDAI = await ethers.getContractFactory("MockDAIMintable");
    const fakedai = await FakeDAI.attach('0xfe0e877f64EcDDC1FEAD698842931C9f5a279bd8');
    
    // call approve on the token
    await fakedai.approve('0xb3E1ef68076bdB0393C21Bc20944A07579430425', "0x033b2e3c9fd0803ce7ffffff");
    
    const daiAllowanceAmount = await fakedai.allowance(owner.address, '0xb3E1ef68076bdB0393C21Bc20944A07579430425')
    
    
    expect(daiAllowanceAmount._hex).to.equal("0x033b2e3c9fd0803ce7ffffff");
  });
  
  it("Fake USDC should allow us to approve tokens for the SwapV1 contract", async function () {
    const [owner] = await ethers.getSigners();

    // assign fake usdc to the contract address
    const FakeUSDC = await ethers.getContractFactory("MockUSDCMintable");
    const fakeusdc = await FakeUSDC.attach('0x6A6cB2fB37970e20384B2f4e2390D31cB6bdA9b2');
    
    // call approve on the token
    await fakeusdc.approve('0xb3E1ef68076bdB0393C21Bc20944A07579430425', "0x033b2e3c9fd0803ce7ffffff");
    
    const usdcAllowanceAmount = await fakeusdc.allowance(owner.address, '0xb3E1ef68076bdB0393C21Bc20944A07579430425')
    
    expect(usdcAllowanceAmount._hex).to.equal("0x033b2e3c9fd0803ce7ffffff");
  });
  
  it("Fake USDT should allow us to approve tokens for the SwapV1 contract", async function () {
    const [owner] = await ethers.getSigners();

    // assign fake usdt to the contract address
    const FakeUSDT = await ethers.getContractFactory("MockUSDTMintable");
    const fakeusdt = await FakeUSDT.attach('0x31474310e0e37dA2483bE1F419124fcCdE931f5F');
    
    // call approve on the token
    await fakeusdt.approve('0xb3E1ef68076bdB0393C21Bc20944A07579430425', "0x033b2e3c9fd0803ce7ffffff");
    
    // get the allowance for the swap contract 
    const usdtAllowanceAmount = await fakeusdt.allowance(owner.address, '0xb3E1ef68076bdB0393C21Bc20944A07579430425');
    
    expect(usdtAllowanceAmount._hex).to.equal("0x033b2e3c9fd0803ce7ffffff");
  });
  
  // Deposit liquidity in pool
  
  // check whether each token has an index in the pool
  it("SwapFlashLoanV1 should have an index for each token", async function () {
    const [owner] = await ethers.getSigners();
    
    // assign the pool's address
    const SwapFlashLoanV1 = await ethers.getContractFactory("SwapFlashLoanV1", {
      libraries: {
        AmplificationUtilsV1: '0x995d60F131Cb511EF71218e6641a8F157A9Be8E3',
        SwapUtilsV1: '0x40579177B9e467d14E98b5D1ad00bd025CfF8E0A',
      },
    });
    const swapflashloanv1 = await SwapFlashLoanV1.attach('0xb3E1ef68076bdB0393C21Bc20944A07579430425');
    
    const DAIindex = await swapflashloanv1.getTokenIndex('0xfe0e877f64EcDDC1FEAD698842931C9f5a279bd8');
    
    //console.log("Here is DAIindex: ", DAIindex);
    
    const USDCindex = await swapflashloanv1.getTokenIndex('0x6A6cB2fB37970e20384B2f4e2390D31cB6bdA9b2');
    
    //console.log("Here is USDCindex: ", USDCindex);
    
    const USDTindex = await swapflashloanv1.getTokenIndex('0x31474310e0e37dA2483bE1F419124fcCdE931f5F');
    
    //console.log("Here is USDTindex: ", USDTindex);
    
    // by not reverting, we have succeeded in this test!
    expect.isTrue(true, "All tokens have an index");
  });
  
  // attempt to deposit into the pool
  it("SwapFlashLoanV1 should allow us to deposit balanced liquidity", async function () {
    const [owner] = await ethers.getSigners();
    
    // first, we need 1000 of each token to do a balanced deposit
    // assign fake dai to the contract address
    const FakeDAI = await ethers.getContractFactory("MockDAIMintable");
    const fakedai = await FakeDAI.attach('0xfe0e877f64EcDDC1FEAD698842931C9f5a279bd8');
    
    console.log("Attached to FakeDAI");
    
    // assign fake usdc to the contract address
    const FakeUSDC = await ethers.getContractFactory("MockUSDCMintable");
    const fakeusdc = await FakeUSDC.attach('0x6A6cB2fB37970e20384B2f4e2390D31cB6bdA9b2');
    
    console.log("Attached to FakeUSDC");
    
    // assign fake usdt to the contract address
    const FakeUSDT = await ethers.getContractFactory("MockUSDTMintable");
    const fakeusdt = await FakeUSDT.attach('0x31474310e0e37dA2483bE1F419124fcCdE931f5F');
    
    console.log("Attached to FAKEUSDT");
    
    // call "mintPreset" on each of them
    // this gets 1000 tokens from each 
    await fakedai.mintPreset();
    await fakeusdc.mintPreset();
    await fakeusdt.mintPreset();
    
    console.log("Minted preset for all tokens!");
    
    // set up SwapFlashLoanV1 
    // assign the pool's address
    const SwapFlashLoanV1 = await ethers.getContractFactory("SwapFlashLoanV1", {
      libraries: {
        AmplificationUtilsV1: '0x995d60F131Cb511EF71218e6641a8F157A9Be8E3',
        SwapUtilsV1: '0x40579177B9e467d14E98b5D1ad00bd025CfF8E0A',
      },
    });
    const swapflashloanv1 = await SwapFlashLoanV1.attach('0xb3E1ef68076bdB0393C21Bc20944A07579430425');

    // before depositing, determine the amount of LP tokens the user held so we can see if it increases reasonably
    const LPTokenV1 = await ethers.getContractFactory("LPTokenV1");
    const lptokenv1 = await LPTokenV1.attach('0x3218216a33f82fe37D3f9bB9B25B62eA0F4eA46e');
    
    const preDepositLPBalance = await lptokenv1.balanceOf(owner.address);

    console.log("preDepositLPBalance: ", preDepositLPBalance);


    // call addLiquidity
    // inputs are:
        // [1000 DAI, 1000 USDC, 1000 USDT]
        // minToMint = 1
        // deadline = january 1 2100
    await swapflashloanv1.addLiquidity(['1000000000000000000', '1000000', '1000000'], 1, 4102513200);
    
    // get balance of LP tokens after depositing
    const postDepositLPBalance = await lptokenv1.balanceOf(owner.address);
    
    assert.isAbove(postDepositBalance, preDepositBalance, "Post deposit balance of LPs is above pre deposit balance");
  });
});

