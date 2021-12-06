//import { formatBytes32String } from "ethers/lib/utils"


const { expect } = require("chai");
const { ethers } = require("hardhat");

const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');


describe("SwapV3-test", function () {
    this.enableTimeouts(false); //TODO do we want this? Why?

    let TIMESTAMP_2121 = 4793820013;

    // declare things up here so they are globally accessible
    let swapflashloan;
    let owner;
    let addr1;
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
        [owner, addr1] = await ethers.getSigners();

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

        // deposit some liquidity (100,100,100)
        const DEPOSIT = await swapflashloan.addLiquidity(["100000000000000000000","100000000","100000000"],1,TIMESTAMP_2121);
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
            
            // set LP cap to 50k LP tokens
            const setLPCap = await swapflashloan.setLPCap("50000000000000000000000");
            
            const swapStorage = await swapflashloan.swapStorage();

            // need to grab the "_hex" attribute of lpCap, and need a lowercase-lettered hex string to match
            // hex string matches the setter above
            expect(swapStorage.lpCap._hex).to.equal("0x0a968163f0a57b400000");  
        });

        it("non-owner can't affect LP cap", async function() {
            // try setting lpcap with addr1
            expectRevert.unspecified(swapflashloan.connect(addr1).setLPCap("25000000000000000000000"));
        });
    });

    describe("Pool operations", function () {
        
        it("Pool should allow deposits", async function() {            
            // set up to read lp balances
            const swapStorage = await swapflashloan.swapStorage();
            const lpTokenAddress = swapStorage.lpToken;

            const LPTokenV3 = await ethers.getContractFactory("LPTokenV3");
            const lpTokenInstance = await LPTokenV3.attach(lpTokenAddress);

            // get pre-deposit balance
            const preDepositBalance = await lpTokenInstance.balanceOf(owner.address);
            
            // conduct deposit
            const DEPOSIT = await swapflashloan.addLiquidity(["100000000000000000000","100000000","100000000"],1,TIMESTAMP_2121);
            
            // get post-deposit balance
            const postDepositBalance = await lpTokenInstance.balanceOf(owner.address);

            // expect numbers are different
            expect(preDepositBalance).to.not.equal(postDepositBalance);
        });

        it("Pool should not allow minting more than LPCap", async function() {
            // at beginning of this function, LPCap should be 10k
            // also at beginning, there should be roughly 300 LP tokens in circulation

            // set LP cap to 500
            const SETLPCAP = await swapflashloan.setLPCap("500000000000000000000");

            // attempt to deposit (500,500,500) - should create about 1500 LP tokens
            // expect this to revert
            expectRevert.unspecified(swapflashloan.addLiquidity(["500000000000000000000","500000000","500000000"],1,TIMESTAMP_2121));
        });

        it("Pool should allow balanced withdrawals", async function() {
            // set up to read lp balances
            const swapStorage = await swapflashloan.swapStorage();
            const lpTokenAddress = swapStorage.lpToken;

            const LPTokenV3 = await ethers.getContractFactory("LPTokenV3");
            const lpTokenInstance = await LPTokenV3.attach(lpTokenAddress);

            // get pre-withdraw balance
            const preWithdrawBalance = await lpTokenInstance.balanceOf(owner.address);
 
            // For all withdrawals, we will need to have approved lptoken transfers by the swap contract
            const APPROVAL = await lpTokenInstance.approve(swapflashloan.address, "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");

            // conduct withdrawal (10 LP Tokens)
            const WITHDRAWAL = await swapflashloan.removeLiquidity("10000000000000000000",[1,1,1],TIMESTAMP_2121);

            // get post-withdraw balance
            const postWithdrawBalance = await lpTokenInstance.balanceOf(owner.address);

            // expect numbers are different
            expect(preWithdrawBalance).to.not.equal(postWithdrawBalance);
        });

        it("Pool should allow imbalanced withdrawals", async function () {
            // set up to read lp balances
            const swapStorage = await swapflashloan.swapStorage();
            const lpTokenAddress = swapStorage.lpToken;

            const LPTokenV3 = await ethers.getContractFactory("LPTokenV3");
            const lpTokenInstance = await LPTokenV3.attach(lpTokenAddress);

            // get pre-withdraw balance
            const preWithdrawBalance = await lpTokenInstance.balanceOf(owner.address);

            // For all withdrawals, we will need to have approved lptoken transfers by the swap contract
            const APPROVAL = await lpTokenInstance.approve(swapflashloan.address, "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");

            // conduct withdrawal (50,10,1) 
            // maxBurnAmount = 100 LP tokens
            const WITHDRAWAL = await swapflashloan.removeLiquidityImbalance(["50000000000000000000","10000000","1000000"],"100000000000000000000",TIMESTAMP_2121);

            // get post-withdrawal balance
            const postWithdrawBalance = await lpTokenInstance.balanceOf(owner.address);

            // expect numbers are different
            expect(preWithdrawBalance).to.not.equal(postWithdrawBalance);
        });

        it("Pool should allow single-token withdrawals", async function () {
            expect(1).to.equal(0); //fails until test is built

            // TODO: find some decent way to chain assertions together
            //  assert that balance of other tokens is same, while only one increases
        });

        it("Pool should allow admin address to be changed", async function() {
            const changeOwner = await swapflashloan.transferOwnership(addr1.address);
            
            const newOwner = await swapflashloan.owner();

            expect(newOwner).to.equal(addr1.address); 
        });

        it("Pool should allow admin fee withdrawal", async function () {
            expect(1).to.equal(0);  //fails until test is built
        });

        it("Pool should allow swap fee changes", async function () {
            expect(1).to.equal(0);  //fails until test is built
        });

        it("Pool should allow admin fee changes", async function () {
            expect(1).to.equal(0);  //fails until test is built
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