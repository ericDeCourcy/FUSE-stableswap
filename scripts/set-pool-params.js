// @dev Set LP cap, fee, adminFee for usd1 and usd3 pools

const { ethers } = require("hardhat");

async function main() {

    console.log("starting script...");
    const timeout = 25000;  //waits 25 seconds between each tx on fuse network
    // this prevents transactions getting sent with the same nonce because a tx is sent
    // before previous tx is mined

    const USD1_ADDRESS = "0x3E192A2Eae22B3DB07a0039E10bCe29097E881B9";
    const USD3_ADDRESS = "0xc98f8bf953647aC364F43D61E5132867c787653F";
    const LP_CAP = "25000000000000000000000"; //25k
    const FEE = "5000000"; // 0.05%
    const ADMIN_FEE = "1000000000"; // 10% (of swap fee)

    const owner = await ethers.getSigners();

    console.log("starting param setting script...");

    console.log("attaching to usd1 pool");
    // attach to usd1 pool
    const USD1 = await ethers.getContractAt("ISwapV3", USD1_ADDRESS);

    console.log("setting USD1 LP Cap");
    // call set LP cap
    await USD1.setLPCap(LP_CAP);

    await new Promise(r => setTimeout(r, timeout));

    console.log("setting usd1 swap fee");
    // call set fee
    await USD1.setSwapFee(FEE);

    await new Promise(r => setTimeout(r, timeout));

    console.log("setting usd1 admin fee");
    // call set adminFee
    await USD1.setAdminFee(ADMIN_FEE);

    await new Promise(r => setTimeout(r, timeout));

    console.log("attaching to usd3 pool");
    // attach to usd3 pool
    const USD3 = await ethers.getContractAt("ISwapV3", USD3_ADDRESS);

    console.log("setting usd3 lp cap");
    // call set LP cap
    await USD3.setLPCap(LP_CAP);

    await new Promise(r => setTimeout(r, timeout));

    console.log("setting usd3 swap fee");
    // call set fee
    await USD3.setSwapFee(FEE);

    await new Promise(r => setTimeout(r, timeout));

    console.log("setting usd3 admin fee");
    // call set adminFee
    await USD3.setAdminFee(ADMIN_FEE);

    await new Promise(r => setTimeout(r, timeout));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
