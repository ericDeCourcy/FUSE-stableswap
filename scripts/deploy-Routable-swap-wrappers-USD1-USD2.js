async function main() {

    const timeout = 25000;

    const owner = await ethers.getSigners();
    const USD1_ADDRESS = "0x3E192A2Eae22B3DB07a0039E10bCe29097E881B9";
    const USD2_ADDRESS = "0xECf95fFBa3e1Eb5f673606bC944fD093BB5D8EeD";

    const USDC_ADDRESS = "0x3E192A2Eae22B3DB07a0039E10bCe29097E881B9";
    const USDT_ADDRESS = "0xFaDbBF8Ce7D5b7041bE672561bbA99f79c532e10";
    const DAI_ADDRESS = "0x3E192A2Eae22B3DB07a0039E10bCe29097E881B9";
    const FUSD_ADDRESS = "0x249BE57637D8B013Ad64785404b24aeBaE9B098B";

    console.log("starting routable wrapper deploy script...");

    // create contract factory for USD1 wrapper
    const RoutableSwapWrapper = await ethers.getContractFactory("RoutableSwapWrapper");

    console.log("about to deploy usd1wrapper");
    // deploy routable swap wrapper for USD1
    // TODO: is this how we pass in constructor args?
    const usd1wrapper = await RoutableSwapWrapper.deploy([DAI_ADDRESS,USDC_ADDRESS,USDT_ADDRESS], USD1_ADDRESS);

    console.log(`deployed usd1wrapper to: ${usd1wrapper.address}`);
    await new Promise(r => setTimeout(r, timeout));


    // transfer tokens to routableWrapper, then call swap
        // we will transfer USDC and swap for DAI
    const ERC20 = await ethers.getContractFactory("ERC20");
    const usdctoken = await ERC20.attach(USDC_ADDRESS);
    const USDC_SEND = await usdctoken.transfer(usd1wrapper.address, 100);

    console.log("transferred tokens");
    await new Promise(r => setTimeout(r, timeout));


    const ROUTABLE_SWAP = await usd1wrapper.swap(USDC_ADDRESS, DAI_ADDRESS, 100, owner.address);
    console.log("conducted swap");

    await new Promise(r => setTimeout(r, timeout));
    console.log("finished")

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
