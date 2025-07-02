const hre = require("hardhat");
async function main() {
    const CircleContract = await hre.ethers.getContractFactory("CircleContract");
    const circleContract = await CircleContract.deploy();
    await circleContract.deployed();
    console.log("CircleContract deployed to:", circleContract.address);
}
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
