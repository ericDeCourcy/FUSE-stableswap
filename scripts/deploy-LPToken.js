async function main() {
  // deploy SwapUtilsV1
  const LPTokenV1 = await ethers.getContractFactory("LPTokenV1");
  const lptokenv1 = await LPTokenV1.deploy();
  
  console.log("LPTokenV1 deployed to:", lptokenv1.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
