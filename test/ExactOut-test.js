const { expect } = require("chai");
const { ethers } = require("hardhat");

const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

// TODO: change all V3 to V4

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
    
        //deploy SwapFlashLoanV3
        const SwapFlashLoan = await ethers.getContractFactory("SwapFlashLoanV4", { libraries: { AmplificationUtilsV4: amplificationUtils.address, SwapUtilsV4: swaputils.address }, });
        swapflashloan = await SwapFlashLoan.deploy();
                
        // deploy LPTokenV3
        const LPToken = await ethers.getContractFactory("LPTokenV4");
        const lptoken = await LPToken.deploy();
                
        // deploy LPRewardsV3
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
        
        // get some fake tokens
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

    it("Check what outputs/inputs should be for both kinds of swap", async function () {

        const bigInput = "99000000000000000000";  //90 DAI

        let swapOutputGivenIn = await swapflashloan.calculateSwap(0,1,bigInput);
        //console.log("outputGivenIn " + swapOutputGivenIn);

        let swapInputGivenOut = await swapflashloan.calculateSwapExactOut(0,1,parseInt(swapOutputGivenIn));
        //console.log("inputGivenOutput: " + swapInputGivenOut);

        let percentError = 100* parseInt(swapInputGivenOut) / parseInt(bigInput);
        console.log("bigInput percentError: " + percentError);

        const mediumInput = "10000000000000000000"; // 10 DAI

        swapOutputGivenIn = await swapflashloan.calculateSwap(0,1,mediumInput);
        
        swapInputGivenOut = await swapflashloan.calculateSwapExactOut(0,1,parseInt(swapOutputGivenIn));
    
        percentError = 100* parseInt(swapInputGivenOut) / parseInt(mediumInput);
        console.log("mediumInput percentError: " + percentError);
    });

});