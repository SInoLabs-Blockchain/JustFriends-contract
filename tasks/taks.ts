import { task } from "hardhat/config";
import { JustFriends } from "../typechain-types";
enum VoteType {
  NONE = 0,
  UPVOTE = 1,
  DOWNVOTE = 2,
}
const JUST_FRIENDS_ADDRESS = "0x2B32fC9beaAfbfB0296403Cc2fa91aB2b16Daf87";
// task("balance", "Prints an account's balance")
//   .addParam("account", "The account's address")
//   .setAction(async ({ account }) => {
//     const balance = await ethers.provider.getBalance(account);

//     console.log(ethers.formatEther(balance), "ETH");
//   });

task("post", "Posts content to the JustFriends platform")
  .addParam("price", "The started price of the content (in ETH)")
  .setAction(async ({ price }, { ethers }) => {
    const [accountFirst, accountSecond, accountThird] = await ethers.getSigners();
    const randomBytes = ethers.randomBytes(32);
    // Convert the bytes to a hex string
    const randomBytes32 = ethers.hexlify(randomBytes);
    const justFriends: JustFriends = await ethers.getContractAt("JustFriends", JUST_FRIENDS_ADDRESS);

    const tx = await justFriends.connect(accountFirst).postContent(randomBytes32, ethers.parseEther(price), true);

    const txResult = await tx.wait();
    console.log("🚀 ~ file: taks.ts:34 ~ .setAction ~ txResult:", txResult?.hash);
    console.log("🚀 ~ file: taks.ts:23 ~ .setAction ~ content hash:", randomBytes32);

    console.log("Content posted successfully!");
  });

task("vote", "Casts a vote on a content")
  .addParam("hash", "The content hash")
  .setAction(async ({ hash }, { ethers }) => {
    const [accountFirst, accountSecond, accountThird] = await ethers.getSigners();
    const justFriends: JustFriends = await ethers.getContractAt("JustFriends", JUST_FRIENDS_ADDRESS);
    const txUpvote = await justFriends.connect(accountSecond).vote(hash, 1);
    let txResult = await txUpvote.wait();
    console.log("🚀 ~ tx upvote hash: ", txResult?.hash);
    const txDownvote = await justFriends.connect(accountThird).vote(hash, 2 as VoteType);
    txResult = await txDownvote.wait();
    console.log("🚀 ~ tx upvote hash: ", txResult?.hash);
    console.log("Vote cast successfully!");
  });

task("trade", "Purchases access to a content")
  .addParam("hash", "The content hash")
  .addParam("price", "The started price of the content")
  .addParam("amount", "Amount of content access")
  .setAction(async ({ hash, price, amount }, { ethers }) => {
    const [accountFirst, accountSecond, accountThird] = await ethers.getSigners();
    const justFriends: JustFriends = await ethers.getContractAt("JustFriends", JUST_FRIENDS_ADDRESS);
    const txBuy = await justFriends.connect(accountThird).buyContentAccess(hash, amount, { value: ethers.parseEther(price) });
    let txResult = await txBuy.wait();
    console.log("🚀 ~ tx buy hash: ", txResult?.hash);
    // const txSell = await justFriends.connect(accountSecond).sellContentAccess(hash, amount);
    // txResult = await txSell.wait();
    // console.log("🚀 ~ tx sell hash: ", txResult?.hash);

    console.log("Content access purchased successfully!");
  });
