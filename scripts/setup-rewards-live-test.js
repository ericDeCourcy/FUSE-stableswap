// This script will do a live-test of the rewards functionality by distributing 24 WFUSE over 24 hours

const { ethers } = require("hardhat");

async function main() {

    const timeout = 25000;  //waits 25 seconds between each tx on fuse network
    // this prevents transactions getting sent with the same nonce because a tx is sent
    // before previous tx is mined

    // declare WFUSE address
    const WFUSE = "0x0BE9e53fd7EDaC9F859882AfdDa116645287C629";
    // declare duration
    const DURATION = 86400;
    // declare amount
    const AMOUNT = "24000000000000000000";
    // declare rewards contract address
    const USD3_REWARDS = "0x8dfc1bf6cf195f1ac3d8fe8f2c9158d60bd0c129";

    // attach to contract
    const rewardsContract = await ethers.getContractAt("LPRewardsV3", USD3_REWARDS);
    const wfuseContract = await ethers.getContractAt("IERC20", WFUSE);

    console.log("setting reward duration");
    // call setRewardsDuration
    await rewardsContract.setNewRewardDuration(DURATION);

    await new Promise(r => setTimeout(r, timeout));

    console.log("approving WFUSE");
    // approve rewards contract to transfer owner's tokens
    await wfuseContract.approve(USD3_REWARDS, AMOUNT);

    await new Promise(r => setTimeout(r, timeout));

    console.log("notifying reward amount");
    // call notifyRewardAmount
    await rewardsContract.notifyRewardAmount(AMOUNT, WFUSE);
    
    await new Promise(r => setTimeout(r, timeout));

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });