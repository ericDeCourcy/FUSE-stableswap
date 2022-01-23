async function main() {
  // We get the contract to deploy
  const RouteHandler = await ethers.getContractFactory("RouteHandler");
  console.log("Deploying RouteHandler.sol")
  const routeHandler = await RouteHandler.deploy();

  console.log("RouteHandler deployed to:", routeHandler.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });