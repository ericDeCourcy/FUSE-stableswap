async function main() {

  // deploy fake DAI
  const FakeDAI = await ethers.getContractFactory("MockDAIMintable");
  const fakedai = await FakeDAI.deploy();
  
  console.log("MockDAIMintable deployed to:", fakedai.address);

  // deploy fake USDC
  const FakeUSDC = await ethers.getContractFactory("MockUSDCMintable");
  const fakeusdc = await FakeUSDC.deploy();
  
  console.log("MockUSDCMintable deployed to:", fakeusdc.address);

  // deploy fake USDT
  const FakeUSDT = await ethers.getContractFactory("MockUSDTMintable");
  const fakeusdt = await FakeUSDT.deploy();
  
  console.log("MockUSDTMintable deployed to:", fakeusdt.address);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
