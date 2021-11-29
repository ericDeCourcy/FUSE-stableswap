//import { formatBytes32String } from "ethers/lib/utils"


const { expect } = require("chai");
const { ethers } = require("hardhat");

const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');


describe("SwapV3-test", function () {
    this.enableTimeouts(false); //TODO do we want this? Why?

    let TIMESTAMP_2121 = 4793820013;

    let swapflashloan;
    let owner;
    let fakeDAIContract;
    let fakeUSDCContract;
    let fakeUSDTContract;

    // test that does nothing should pass with no errors
    it("Test which does nothing should pass", async function() {
        expect(true).to.equal(true);
    });

    // deploy the fake pool
    beforeEach(async function () {
        // set owner
        [owner] = await ethers.getSigners();

        FakeDAIFactory = await ethers.getContractFactory("MockDAIMintable");
        fakeDAIContract = await FakeDAIFactory.deploy();

        FakeUSDCFactory = await ethers.getContractFactory("MockUSDCMintable");
        fakeUSDCContract = await FakeUSDCFactory.deploy();

        FakeUSDTFactory = await ethers.getContractFactory("MockUSDTMintable");
        fakeUSDTContract = await FakeUSDTFactory.deploy();

        // deploy SwapUtils 
        const SwapUtils = await ethers.getContractFactory("SwapUtilsV3");
        const swaputils = await SwapUtils.deploy();
    
        // deploy AmplificationUtils
        const AmplificationUtils = await ethers.getContractFactory("AmplificationUtilsV3");
        const amplificationUtils = await AmplificationUtils.deploy();          
    
        //deploy SwapFlashLoanV3
        const SwapFlashLoan = await ethers.getContractFactory("SwapFlashLoanV3", { libraries: { AmplificationUtilsV3: amplificationUtils.address, SwapUtilsV3: swaputils.address }, });
        swapflashloan = await SwapFlashLoan.deploy();
                
        // deploy LPTokenV3
        const LPToken = await ethers.getContractFactory("LPTokenV3");
        const lptoken = await LPToken.deploy();
                
        // deploy LPRewardsV3
        const LPRewards = await ethers.getContractFactory("LPRewardsV3");
        const lprewards = await LPRewards.deploy();
    
        // deploy deployer
        const Deployer = await ethers.getContractFactory("SwapDeployerV3");
        const deployer = await Deployer.deploy();

        // initialize new pool FROM DEPLOYER
        const INIT = await deployer.deploy(swapflashloan.address, [fakeDAIContract.address, fakeUSDCContract.address, fakeUSDTContract.address], [18, 6, 6], "FSS-FAKE-DAI-USDC-USDT-V3", "LP-FAKE-USD-V3", 100, 100, 100, lptoken.address, lprewards.address);

        // initialize swapflashloan instance
        // this makes it easier to run tests on, since we know the address of swapflashloan (deployer creates new address and is more difficult to get the address of swap)
        const INIT_STANDALONE = await swapflashloan.initialize([fakeDAIContract.address, fakeUSDCContract.address, fakeUSDTContract.address], [18, 6, 6], "FSS-FAKE-DAI-USDC-USDT-V3", "LP-FAKE-USD-V3", 100, 100, 100, lptoken.address, lprewards.address);
        
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
    });

    describe("Deployment", function () {

        it("Should be able to access swapFlashLoan from outside deploying test", async function() {
            expect(swapflashloan.address).to.not.equal(0);
        });

        it("Should be able to get the rewards token address", async function() {
            const rewardToken = await swapflashloan.lpRewardsAddress();

            expect(rewardToken).to.not.equal(0);
        });

        it("Owner of rewards should be msg.sender", async function() {
            const rewardToken = await swapflashloan.lpRewardsAddress();

            const LPRewards = await ethers.getContractFactory("LPRewardsV3");
            const rewardTokenInstance = await LPRewards.attach(rewardToken);

            const rewardTokenOwner = await rewardTokenInstance.owner();

            expect(rewardTokenOwner).to.equal(owner.address);
        });

        it("should only allow owner to affect LP cap", async function() {
            
            // TODO: this test
            
            expect(1).to.equal(0);      // this test fails until we actually build it out
        });
    });

    describe("Pool operations", function () {
        
        it("Pool should allow deposits", async function() {            
            const DEPOSIT = await swapflashloan.addLiquidity(["100000000000000000000","100000000","100000000"],1,TIMESTAMP_2121);
            
        });
    });



    // Pool allows withdrawal
        // do withdraw
        // check LP tokens taken away
        // check token balances increase

    // Pool allows imbalanced withdraw

    // Pool allows single token withdraw

    // Pool allows LP cap setting

    // Pool allows admin variable changes

    // Pool allows switching admin

});