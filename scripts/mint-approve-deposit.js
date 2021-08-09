async function main() {
    
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
    
    await fakedai.approve('0xb3E1ef68076bdB0393C21Bc20944A07579430425', '100000000000000000000');
    await fakeusdc.approve('0xb3E1ef68076bdB0393C21Bc20944A07579430425', '100000000');
    await fakeusdt.approve('0xb3E1ef68076bdB0393C21Bc20944A07579430425', '100000000');
    
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
    
    const [owner] = await ethers.getSigners();
    
    // get balance of LP tokens after depositing
    const postDepositLPBalance = await lptokenv1.balanceOf(owner.address);
    
    console.log("post deposit lp balance: ", postDepositLPBalance);
  };

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
