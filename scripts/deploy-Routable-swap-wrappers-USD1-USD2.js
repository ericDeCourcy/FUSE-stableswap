const { ethers } = require("ethers");

async function main() {

    const timeout = 25000;

    const owner = await ethers.getSigners();
    const USD1_ADDRESS = //TODO
    const USD2_ADDRESS = //TODO

    const USDC_ADDRESS = //TODO
    const USDT_ADDRESS = //TODO
    const DAI_ADDRESS = //TODO
    const FUSD_ADDRESS = //TODO

    console.log("starting routable wrapper deploy script...");

    // create contract factory for USD1 wrapper
    const RoutableSwapWrapper = await ethers.getContractFactory("RoutableSwapWrapper");

    // deploy routable swap wrapper for USD1
    // TODO: is this how we pass in constructor args?
    const usd1wrapper = await RoutableSwapWrapper.deploy([DAI_ADDRESS,USDC_ADDRESS,USDT_ADDRESS], USD1_ADDRESS);

    // transfer tokens to routableWrapper, then call swap
        // we will transfer USDC and swap for DAI
    const ERC20 = await ethers.getContractFactory("ERC20");
    const usdctoken = await ERC20.attach(USDC_ADDRESS);
    const USDC_SEND = await usdctoken.transfer(usd1wrapper.address, 100);

    const ROUTABLE_SWAP = await usd1wrapper.swap(USDC_ADDRESS, DAI_ADDRESS, 100, owner.address);
    

}