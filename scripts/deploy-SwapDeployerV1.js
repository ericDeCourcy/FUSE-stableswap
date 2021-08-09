async function main() {
  // deploy SwapUtilsV1
  const SwapDeployerV1 = await ethers.getContractFactory("SwapDeployerV1");
  const swapdeployerv1 = await SwapDeployerV1.deploy();
  
  console.log("SwapDeployerV1 deployed to:", swapdeployerv1.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
