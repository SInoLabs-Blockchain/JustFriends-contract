import { ethers } from "hardhat";

async function main() {
  // const contentAccessContract = await ethers.deployContract("ContentAccess", [""]);
  // await contentAccessContract.waitForDeployment();
  // console.log(`ContentAccessContract is deployed at ${await contentAccessContract.getAddress()}`);
  const justFriendsContract = await ethers.deployContract("JustFriends", ["0x0bc68d7a06259006ae4cb3B8eFF737a46bF5912e", 5, 5, 3, 2]);
  await justFriendsContract.waitForDeployment();
  console.log(`JustFriendsContract is deployed at ${await justFriendsContract.getAddress()}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
