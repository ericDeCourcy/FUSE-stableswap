//import { formatBytes32String } from "ethers/lib/utils"


const { expect } = require("chai");
const { ethers } = require("hardhat");

const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');


describe("SwapV4-test", function () {
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
        // fee should be 10e7 because that's 0.1%
        // admin fee should be 10e9 because thats 10% - this means 10% of 0.1%... so admin gets 0.01% of each trade, LPs get 0.09% 
        const INIT_STANDALONE = await swapflashloan.initialize([fakeDAIContract.address, fakeUSDCContract.address, fakeUSDTContract.address], [18, 6, 6], "FSS-FAKE-DAI-USDC-USDT-V4", "LP-FAKE-USD-V4", 100, 10000000, 1000000000, lptoken.address, lprewards.address);

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

    describe("Deployment", function () {

        it("Should be able to access swapFlashLoan from outside deploying test", async function() {
            expect(swapflashloan.address).to.not.equal(0);
        });

        it("Should be able to get the rewards token address", async function() {
            const rewardToken = await swapflashloan.lpRewardsAddress();

            expect(rewardToken).to.not.equal(0);
        });

        it("Owner of rewards should be msg.sender", async function() {

            const rewardTokenOwner = await rewardsContract.owner();

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

            const LPTokenV4 = await ethers.getContractFactory("LPTokenV4");
            const lpTokenInstance = await LPTokenV4.attach(lpTokenAddress);

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

            const LPTokenV4 = await ethers.getContractFactory("LPTokenV4");
            const lpTokenInstance = await LPTokenV4.attach(lpTokenAddress);

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

            const LPTokenV4 = await ethers.getContractFactory("LPTokenV4");
            const lpTokenInstance = await LPTokenV4.attach(lpTokenAddress);

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
            // check admin token balances before claiming fees
            const DaiBalanceBefore = await fakeDAIContract.balanceOf(owner.address);
            const UsdcBalanceBefore = await fakeUSDCContract.balanceOf(owner.address);
            const UsdtBalanceBefore = await fakeUSDTContract.balanceOf(owner.address);

            // approve LP token burn
            const swapStorage = await swapflashloan.swapStorage();          // get swap info
            const lpTokenAddress = swapStorage.lpToken;                     // get lp token
            const LPTokenV4 = await ethers.getContractFactory("LPTokenV4"); // get lp token contract artifact
            const lpTokenInstance = await LPTokenV4.attach(lpTokenAddress); // attach lp address to contract artifact
            const APPROVAL = await lpTokenInstance.approve(swapflashloan.address, "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");

            // withdraw ONLY one DAI
            const SINGLE_TOKEN_WITHDRAW = await swapflashloan.removeLiquidityOneToken("1000000000000000000", 0, 1, TIMESTAMP_2121);

            // check token balances after
            const DaiBalanceAfter = await fakeDAIContract.balanceOf(owner.address);
            const UsdcBalanceAfter = await fakeUSDCContract.balanceOf(owner.address);
            const UsdtBalanceAfter = await fakeUSDTContract.balanceOf(owner.address);

            //  assert that balance of other tokens is same, while only one increases
            expect(DaiBalanceBefore._hex).to.not.equal(DaiBalanceAfter._hex);
            expect(UsdcBalanceBefore._hex).to.equal(UsdcBalanceAfter._hex);
            expect(UsdtBalanceBefore._hex).to.equal(UsdtBalanceAfter._hex);
        });

        it("Pool should allow admin address to be changed", async function() {
            const changeOwner = await swapflashloan.transferOwnership(addr1.address);
            
            const newOwner = await swapflashloan.owner();

            expect(newOwner).to.equal(addr1.address); 
        });

        it("Pool should allow admin fee withdrawal", async function () {
            // first, conduct a few swaps to generate fees
            const SWAP_1 = await swapflashloan.swap(0,1,"100000000000000000000",1,TIMESTAMP_2121);
            const SWAP_2 = await swapflashloan.swap(1,2,"100000000",1,TIMESTAMP_2121);
            const SWAP_3 = await swapflashloan.swap(2,0,"100000000",1,TIMESTAMP_2121);

            // check admin token balances before claiming fees
            const DaiBalanceBefore = await fakeDAIContract.balanceOf(owner.address);
            const UsdcBalanceBefore = await fakeUSDCContract.balanceOf(owner.address);
            const UsdtBalanceBefore = await fakeUSDTContract.balanceOf(owner.address);

            // claim the fees
            const CLAIM_FEES = await swapflashloan.withdrawAdminFees();

            // check token balances after
            const DaiBalanceAfter = await fakeDAIContract.balanceOf(owner.address);
            const UsdcBalanceAfter = await fakeUSDCContract.balanceOf(owner.address);
            const UsdtBalanceAfter = await fakeUSDTContract.balanceOf(owner.address);

            /*
            console.log(`DAI balances: ${DaiBalanceBefore}, ${DaiBalanceAfter}`);
            console.log(`USDC balances: ${UsdcBalanceBefore}, ${UsdcBalanceAfter}`);
            console.log(`USDT balances: ${UsdtBalanceBefore}, ${UsdtBalanceAfter}`);
            */

            // assert that after != before
            expect(DaiBalanceBefore._hex).to.not.equal(DaiBalanceAfter._hex);
            expect(UsdcBalanceBefore._hex).to.not.equal(UsdcBalanceAfter._hex);  
            expect(UsdtBalanceBefore._hex).to.not.equal(UsdtBalanceAfter._hex);
        });

        it("Pool should allow swap fee changes", async function () {
            // get swap fee before
            const swapStorageBefore = await swapflashloan.swapStorage();
            const swapFeeBefore = swapStorageBefore.swapFee._hex;

            // set swap fee to 0.2% (should be 0.1% initially)
            const SET_SWAP_FEE = await swapflashloan.setSwapFee("20000000");

            // get swap fee after
            const swapStorageAfter = await swapflashloan.swapStorage();
            const swapFeeAfter = swapStorageAfter.swapFee._hex;

            // assert not equal
            expect(swapFeeBefore).to.not.equal(swapFeeAfter);
        });

        it("Pool should allow admin fee changes", async function () {
            // get admin fee before
            const swapStorageBefore = await swapflashloan.swapStorage();
            const adminFeeBefore = swapStorageBefore.adminFee._hex;

            // set admin fee to 20% (should be 10% initially)
            const SET_ADMIN_FEE = await swapflashloan.setAdminFee("2000000000");

            // get swap fee after
            const swapStorageAfter = await swapflashloan.swapStorage();
            const adminFeeAfter = swapStorageAfter.adminFee._hex;

            // assert not equal
            expect(adminFeeBefore).to.not.equal(adminFeeAfter);
        });
    });
});