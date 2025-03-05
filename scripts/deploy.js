async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const Arbitrage = await ethers.getContractFactory("Arbitrage");
  const arbitrage = await Arbitrage.deploy();
  console.log("Arbitrage contract deployed to:", arbitrage.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
