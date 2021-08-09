async function main() {

  // deploy fake DAI
  const FakeDAI = await ethers.getContractFactory("MockDAIMintable");
  const fakedai = await FakeDAI.attach('0xfe0e877f64EcDDC1FEAD698842931C9f5a279bd8');
  await fakedai.mintPreset();

  // deploy fake USDC
  const FakeUSDC = await ethers.getContractFactory("MockUSDCMintable");
  const fakeusdc = await FakeUSDC.attach('0x6A6cB2fB37970e20384B2f4e2390D31cB6bdA9b2');
  await fakeusdc.mintPreset();

  // deploy fake USDT
  const FakeUSDT = await ethers.getContractFactory("MockUSDTMintable");
  const fakeusdt = await FakeUSDT.attach('0x31474310e0e37dA2483bE1F419124fcCdE931f5F');
  await fakeusdt.mintPreset();
  
  console.log("preset token amounts minted");

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
