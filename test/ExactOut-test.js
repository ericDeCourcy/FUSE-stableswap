const { expect } = require("chai");
const { ethers } = require("hardhat");

const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');


describe("ExactOut-test", function () {
    this.enableTimeouts(false); //TODO do we want this? Why?

    let TIMESTAMP_2121 = 4793820013;

    // declare things up here so they are globally accessible
    let swapflashloan;
    let owner;
    let addr1;
    let fakeDAIContract;
    let fakeUSDCContract;
    let fakeUSDTContract;
    let rewardsContract;

    // test that does nothing should pass with no errors
    it("Test which does nothing should pass", async function() {
        expect(true).to.equal(true);
    });

    beforeEach(async function () {
        // set owner
        [owner, addr1] = await ethers.getSigners();

        FakeDAIFactory = await ethers.getContractFactory("MockDAIMintable");
        fakeDAIContract = await FakeDAIFactory.deploy();

        FakeUSDCFactory = await ethers.getContractFactory("MockUSDCMintable");
        fakeUSDCContract = await FakeUSDCFactory.deploy();

        FakeUSDTFactory = await ethers.getContractFactory("MockUSDTMintable");
        fakeUSDTContract = await FakeUSDTFactory.deploy();

        // deploy SwapUtils 
        const SwapUtils = await ethers.getContractFactory("SwapUtilsV4");
        const swaputils = await SwapUtils.deploy();
    
        // deploy AmplificationUtils
        const AmplificationUtils = await ethers.getContractFactory("AmplificationUtilsV4");
        const amplificationUtils = await AmplificationUtils.deploy();          
    
        //deploy SwapFlashLoanV4
        const SwapFlashLoan = await ethers.getContractFactory("SwapFlashLoanV4", { libraries: { AmplificationUtilsV4: amplificationUtils.address, SwapUtilsV4: swaputils.address }, });
        swapflashloan = await SwapFlashLoan.deploy();
                
        // deploy LPTokenV4
        const LPToken = await ethers.getContractFactory("LPTokenV4");
        const lptoken = await LPToken.deploy();
                
        // deploy LPRewardsV4
        const LPRewards = await ethers.getContractFactory("LPRewardsV4");
        const lprewards = await LPRewards.deploy();
    
        // deploy deployer
        const Deployer = await ethers.getContractFactory("SwapDeployerV4");
        const deployer = await Deployer.deploy();

        // initialize new pool FROM DEPLOYER
        const INIT = await deployer.deploy(swapflashloan.address, [fakeDAIContract.address, fakeUSDCContract.address, fakeUSDTContract.address], [18, 6, 6], "FSS-FAKE-DAI-USDC-USDT-V4", "LP-FAKE-USD-V4", 100, 100, 100, lptoken.address, lprewards.address);

        // initialize swapflashloan instance
        // this makes it easier to run tests on, since we know the address of swapflashloan (deployer creates new address and is more difficult to get the address of swap)
        // fee should be 5e7 because that's 0.05%
        // admin fee should be 10e9 because thats 10% - this means 10% of 0.1%... so admin gets 0.01% of each trade, LPs get 0.09% 
        const INIT_STANDALONE = await swapflashloan.initialize([fakeDAIContract.address, fakeUSDCContract.address, fakeUSDTContract.address], [18, 6, 6], "FSS-FAKE-DAI-USDC-USDT-V4", "LP-FAKE-USD-V4", 100, 50000000, 1000000000, lptoken.address, lprewards.address);
        
        // get some fake tokens - 1000 of each
        const DAI_MINT = await fakeDAIContract.mintPreset();
        const USDC_MINT = await fakeUSDCContract.mintPreset();
        const USDT_MINT = await fakeUSDTContract.mintPreset();
    
        // approve all the tokens
        const DAI_APPROVE = await fakeDAIContract.approve(swapflashloan.address, "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        const USDC_APPROVE = await fakeUSDCContract.approve(swapflashloan.address, "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        const USDT_APPROVE = await fakeUSDTContract.approve(swapflashloan.address, "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");    

        // set the LP cap to 10k
        const SET_LP_CAP = await swapflashloan.setLPCap("10000000000000000000000");

        // deposit some liquidity (100,100,100)
        const DEPOSIT = await swapflashloan.addLiquidity(["100000000000000000000","100000000","100000000"],1,TIMESTAMP_2121);
    
        const rewardToken = await swapflashloan.lpRewardsAddress();

        rewardsContract = await LPRewards.attach(rewardToken);
    });

    it("Check percent error between inputs when sending in DAI", async function () {

        const bigInput = "99000000000000000000";  //90 DAI

        let swapOutputGivenIn = await swapflashloan.calculateSwap(0,1,bigInput);
        //console.log("outputGivenIn " + swapOutputGivenIn);

        let swapInputGivenOut = await swapflashloan.calculateSwapExactOut(0,1,parseInt(swapOutputGivenIn));
        //console.log("inputGivenOutput: " + swapInputGivenOut);

        let percentError = 100* parseInt(swapInputGivenOut) / parseInt(bigInput);   //percent error is difference between what is paid for an output calculated via "exactOut", and the amount paid in which resulted in same output via regular swap function
        console.log("bigInput percentError: " + percentError);

        const mediumInput = "10000000000000000000"; // 10 DAI

        swapOutputGivenIn = await swapflashloan.calculateSwap(0,1,mediumInput);
        
        swapInputGivenOut = await swapflashloan.calculateSwapExactOut(0,1,parseInt(swapOutputGivenIn));
    
        percentError = 100* parseInt(swapInputGivenOut) / parseInt(mediumInput);
        console.log("mediumInput percentError: " + percentError);

        const smallInput = "100000000000000000"; // 0.1 DAI

        swapOutputGivenIn = await swapflashloan.calculateSwap(0,1,smallInput);

        swapInputGivenOut = await swapflashloan.calculateSwap(0,1,swapOutputGivenIn);

        percentError = 100* parseInt(swapInputGivenOut)/ parseInt(smallInput);
        console.log("smallInput percentError: " + percentError);
    });

    it("Check percent error between inputs sending in USDC for DAI", async function () {

        /*
        const bigInput = "99000000"; //99 USDC

        let swapOutputGivenIn = await swapflashloan.calculateSwap(1,0,bigInput);

        // TODO fix the issue here
        let swapInputGivenOut = await swapflashloan.calculateSwapExactOut(1,0,parseInt(swapOutputGivenIn)); //parseInt seems to cause error
        // try applying this answer from stackoverflow: https://stackoverflow.com/questions/10959255/javascript-bigint-js-how-to-divide-big-numbers

        let percentError = 100 * parseInt(swapInputGivenOut) / parseInt(bigInput);
        console.log("bigInput percentError: " + percentError);

        const mediumInput = "10000000"; //99 USDC

        swapOutputGivenIn = await swapflashloan.calculateSwap(1,0,mediumInput);

        swapInputGivenOut = await swapflashloan.calculateSwapExactOut(1,0,parseInt(swapOutputGivenIn));

        percentError = 100* parseInt(swapInputGivenOut)/ parseInt(mediumInput);
        console.log("mediumInput percentError: " + percentError);

        const smallInput = "100000"; // 0.1 USDC

        swapOutputGivenIn = await swapflashloan.calculateSwap(1,0,smallInput);

        swapInputGivenOut = await swapflashloan.calculateSwap(1,0,swapOutputGivenIn);

        percentError = 100* parseInt(swapInputGivenOut)/ parseInt(smallInput);
        console.log("smallInput percentError: " + percentError);*/
    });

    it("Large exactOut swaps work as predicted", async function () {
        
        const swapOutput = "50000000000000000000"; // 50 DAI

        let swapInputGivenOut = await swapflashloan.calculateSwapExactOut(1,0,swapOutput);

        const maxDx = "1000000000"; // 1000 USDC
        const deadline = "4797998105"; // jan 16 2122

        let calculatedInput = await swapflashloan.calculateSwapExactOut(1,0,swapOutput);
        await swapflashloan.swapExactOut(1,0,swapOutput, maxDx, deadline);

        // expect that balance of USDC is 900 - swapInputGivenOut
        let USDCBalance = await fakeUSDCContract.balanceOf(owner.address);
        
        let USDCSpent = 900000000 - parseInt(USDCBalance._hex, 16);

        expect(parseInt(swapInputGivenOut._hex,16)).to.equal(USDCSpent);
    });

    it("Medium exactOut swaps work as predicted", async function () {

        const swapOutput = "5000000000000000000"; // 5 DAI

        let swapInputGivenOut = await swapflashloan.calculateSwapExactOut(1,0,swapOutput);

        const maxDx = "1000000000"; // 1000 USDC
        const deadline = "4797998105"; // jan 16 2122

        let calculatedInput = await swapflashloan.calculateSwapExactOut(1,0,swapOutput);
        await swapflashloan.swapExactOut(1,0,swapOutput, maxDx, deadline);

        // expect that balance of USDC is 900 - swapInputGivenOut
        let USDCBalance = await fakeUSDCContract.balanceOf(owner.address);
        
        let USDCSpent = 900000000 - parseInt(USDCBalance._hex, 16);

        expect(parseInt(swapInputGivenOut._hex,16)).to.equal(USDCSpent);
    });

    it("Small exactOut swaps work as predicted", async function () {
        
        const swapOutput = "100000000000000000"; // 0.1 DAI

        let swapInputGivenOut = await swapflashloan.calculateSwapExactOut(1,0,swapOutput);

        const maxDx = "1000000000"; // 1000 USDC
        const deadline = "4797998105"; // jan 16 2122

        let calculatedInput = await swapflashloan.calculateSwapExactOut(1,0,swapOutput);
        await swapflashloan.swapExactOut(1,0,swapOutput, maxDx, deadline);

        // expect that balance of USDC is 900 - swapInputGivenOut
        let USDCBalance = await fakeUSDCContract.balanceOf(owner.address);
        
        let USDCSpent = 900000000 - parseInt(USDCBalance._hex, 16);

        expect(parseInt(swapInputGivenOut._hex,16)).to.equal(USDCSpent);
    });
});