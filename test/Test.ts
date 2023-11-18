import { mineUpTo, setBalance, mine } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { JustFriends } from "../typechain-types";

describe("JustFriends", function () {
  let [creator, user_1, user_2, user_3, user_4, protocolFeeDestination]: SignerWithAddress[] = [];
  let contentHash: string;
  const protocolFeePercentBase = 5;
  const creatorFeePercentBase = 5;
  const extraFeePercentBase = 3;
  const loyalFeePercentBase = 1;
  const loyalFanLength = 3;
  const startedPrice = ethers.parseEther("0.01");
  const freePrice = 0;
  const periodBlock = 100000;
  const startBlock = 1000000;
  const defaultBalance = ethers.parseEther("10000000000");
  let justFriends: JustFriends;

  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deploy() {
    // Contracts are deployed using the first signer/account by default
    [creator, user_1, user_2, user_3, user_4, protocolFeeDestination] = await ethers.getSigners();
    const JustFriendsContract = await ethers.getContractFactory("JustFriends");

    justFriends = await JustFriendsContract.deploy(
      protocolFeeDestination,
      protocolFeePercentBase,
      creatorFeePercentBase,
      extraFeePercentBase,
      loyalFeePercentBase,
      loyalFanLength
    );
    contentHash = ethers.keccak256(ethers.randomBytes(42));
  }
  beforeEach(async () => {
    await deploy();
  });
  describe("post", function () {
    it("should succeed to post a paid post", async function () {
      const postTx = await justFriends.postContent(contentHash, startedPrice, true);
      await expect(postTx).to.be.emit(justFriends, "ContentCreated").withArgs(contentHash, creator.address, startedPrice, true);
      const contentId = (await justFriends.contentList(contentHash)).accessTokenId;
      expect(contentId).to.be.equal(1);
      expect(await justFriends.balanceOf(creator.address, contentId.toString())).to.be.equal(1);
    });
    it("Should failed to post 2 same content", async function () {
      await justFriends.postContent(contentHash, startedPrice, false);
      const postTx = justFriends.postContent(contentHash, startedPrice, true);
      expect(postTx).to.be.revertedWithCustomError(justFriends, "InvalidContent").withArgs(contentHash);
    });
  });
  describe("vote", function () {
    let periodId: number;
    let blockNumber;
    beforeEach(async () => {
      mineUpTo(startBlock);
      await justFriends.postContent(contentHash, startedPrice, false);
      blockNumber = await ethers.provider.getBlockNumber();
      periodId = Math.floor(blockNumber / periodBlock);
    });
    it("Should succeed to upvote", async function () {
      const upvoteTx = await justFriends.connect(user_1).vote(contentHash, 2);
      await expect(upvoteTx).to.be.emit(justFriends, "Upvoted").withArgs(contentHash, user_1.address, creator.address);
      expect(await justFriends.userReactions(user_1.address, contentHash)).to.be.equal(2);
      expect((await justFriends.loyalFanRecords(user_1.address, creator.address, periodId)).claimed).to.be.equal(false);
      expect((await justFriends.loyalFanRecords(user_1.address, creator.address, periodId)).loyalty).to.be.equal(1);
      const periodData = await justFriends.periodList(creator.address, periodId);
      const loyaltyList = await justFriends.getListLoyalty(creator.address, periodId);
      expect(loyaltyList.length).to.be.equal(1);
      expect(loyaltyList[0]).to.be.equal(user_1.address);
    });
    it("Should succeed to downvote", async function () {
      const downvoteTx = await justFriends.connect(user_1).vote(contentHash, 1);
      await expect(downvoteTx).to.be.emit(justFriends, "Downvoted").withArgs(contentHash, user_1.address, creator.address);
      expect(await justFriends.userReactions(user_1.address, contentHash)).to.be.equal(1);
      expect((await justFriends.loyalFanRecords(user_1.address, creator.address, periodId)).claimed).to.be.equal(false);
      expect((await justFriends.loyalFanRecords(user_1.address, creator.address, periodId)).loyalty).to.be.equal(1);
      const periodData = await justFriends.periodList(creator.address, periodId);
      const loyaltyList = await justFriends.getListLoyalty(creator.address, periodId);
      expect(loyaltyList.length).to.be.equal(1);
      expect(loyaltyList[0]).to.be.equal(user_1.address);
    });
    it("Should be able to re-vote", async function () {
      await justFriends.connect(user_1).vote(contentHash, 2);
      await justFriends.connect(user_1).vote(contentHash, 1);
    });
    it("Should fail to vote the same reaction in one post", async function () {
      await justFriends.connect(user_1).vote(contentHash, 2);
      const reVoteTx = justFriends.connect(user_1).vote(contentHash, 2);
      await expect(reVoteTx).to.be.revertedWithCustomError(justFriends, "DuplicateVoting");
    });
    it("Loyal fan checker", async function () {
      await justFriends.connect(user_1).vote(contentHash, 2);
      await justFriends.connect(user_2).vote(contentHash, 2);
      await justFriends.connect(user_3).vote(contentHash, 2);
      await justFriends.connect(user_4).vote(contentHash, 2);
      let loyaltyList = await justFriends.getListLoyalty(creator.address, periodId);
      expect(loyaltyList.length).to.be.equal(3);
      expect(loyaltyList[0]).to.be.equal(user_1.address);
      expect(loyaltyList[1]).to.be.equal(user_2.address);
      expect(loyaltyList[2]).to.be.equal(user_3.address);
      // new post
      const contentHashSecond = ethers.keccak256(ethers.randomBytes(42));
      await justFriends.postContent(contentHashSecond, startedPrice, false);
      await justFriends.connect(user_4).vote(contentHashSecond, 2);
      loyaltyList = await justFriends.getListLoyalty(creator.address, periodId);
      expect((await justFriends.loyalFanRecords(user_4.address, creator.address, periodId)).loyalty).to.be.equal(2);

      expect(loyaltyList.length).to.be.equal(3);
      expect(loyaltyList[0]).to.be.equal(user_1.address);
      expect(loyaltyList[1]).to.be.equal(user_2.address);
      expect(loyaltyList[2]).to.be.equal(user_4.address);
      mineUpTo(startBlock + periodBlock);
      const contentHashThird = ethers.keccak256(ethers.randomBytes(42));
      await justFriends.postContent(contentHashThird, startedPrice, false);
      await justFriends.connect(user_4).vote(contentHashThird, 2);
      const currentPeriodId = periodId + 1;
      const lastPeriodData = await justFriends.periodList(creator.address, periodId);
      expect(lastPeriodData.isClose).to.be.equal(true);
      loyaltyList = await justFriends.getListLoyalty(creator.address, currentPeriodId);
      expect((await justFriends.loyalFanRecords(user_4.address, creator.address, currentPeriodId)).loyalty).to.be.equal(1);
      expect(loyaltyList.length).to.be.equal(1);
      expect(loyaltyList[0]).to.be.equal(user_4.address);
    });
  });
  describe("buy/sell", function () {
    let periodId: number;
    let blockNumber;
    let contentId: bigint;
    beforeEach(async () => {
      mineUpTo(startBlock);
      await justFriends.postContent(contentHash, startedPrice, true);
      contentId = (await justFriends.contentList(contentHash)).accessTokenId;

      blockNumber = await ethers.provider.getBlockNumber();
      periodId = Math.floor(blockNumber / periodBlock);
      await setBalance(user_1.address, defaultBalance);
      await setBalance(user_2.address, defaultBalance);
      await setBalance(user_3.address, defaultBalance);
      await setBalance(user_4.address, defaultBalance);
    });

    it("Should succeed to buy post", async function () {
      let buyPrice = await justFriends.getBuyPrice(contentHash, 1);
      console.log("🚀 ~ file: Test.ts:147 ~ buyPrice:", ethers.formatEther(buyPrice));
      const buyTx = await justFriends.connect(user_1).buyContentAccess(contentHash, "1", { value: buyPrice });
      await expect(buyTx).to.be.emit(justFriends, "AccessPurchased").withArgs(contentHash, user_1.address, 1, buyPrice);
      expect((await justFriends.loyalFanRecords(user_1.address, creator.address, periodId)).loyalty).to.be.equal(3);
      let loyaltyList = await justFriends.getListLoyalty(creator.address, periodId);
      expect(loyaltyList.length).to.be.equal(1);
      expect(loyaltyList[0]).to.be.equal(user_1.address);
      expect(await justFriends.balanceOf(user_1.address, contentId.toString())).to.be.equal(1);

      buyPrice = await justFriends.getBuyPrice(contentHash, 10);
      console.log("🚀 ~ file: Test.ts:150 ~ buyPrice:", ethers.formatEther(buyPrice));
      const buyTx2 = await justFriends.connect(user_1).buyContentAccess(contentHash, "10", { value: buyPrice });
      await expect(buyTx2).to.be.emit(justFriends, "AccessPurchased").withArgs(contentHash, user_1.address, 10, buyPrice);
      expect((await justFriends.loyalFanRecords(user_1.address, creator.address, periodId)).loyalty).to.be.equal(3 + 3 * 10);
      loyaltyList = await justFriends.getListLoyalty(creator.address, periodId);
      expect(loyaltyList.length).to.be.equal(1);
      expect(loyaltyList[0]).to.be.equal(user_1.address);
      expect(await justFriends.balanceOf(user_1.address, contentId.toString())).to.be.equal(11);

      buyPrice = await justFriends.getBuyPrice(contentHash, 1);
      console.log("🚀 ~ file: Test.ts:150 ~ buyPrice:", ethers.formatEther(buyPrice));
      const buyTx3 = await justFriends.connect(user_2).buyContentAccess(contentHash, "1", { value: buyPrice });
      await expect(buyTx3).to.be.emit(justFriends, "AccessPurchased").withArgs(contentHash, user_2.address, 1, buyPrice);
      expect((await justFriends.loyalFanRecords(user_2.address, creator.address, periodId)).loyalty).to.be.equal(3);
      loyaltyList = await justFriends.getListLoyalty(creator.address, periodId);
      expect(loyaltyList.length).to.be.equal(2);
      expect(loyaltyList[0]).to.be.equal(user_1.address);
      expect(loyaltyList[1]).to.be.equal(user_2.address);
      expect(await justFriends.balanceOf(user_2.address, contentId.toString())).to.be.equal(1);

      buyPrice = await justFriends.getBuyPrice(contentHash, 100);
      console.log("🚀 ~ file: Test.ts:150 ~ buyPrice:", ethers.formatEther(buyPrice));
      const buyTx4 = await justFriends.connect(user_3).buyContentAccess(contentHash, "100", { value: buyPrice });
      await expect(buyTx4).to.be.emit(justFriends, "AccessPurchased").withArgs(contentHash, user_3.address, 100, buyPrice);
      expect((await justFriends.loyalFanRecords(user_3.address, creator.address, periodId)).loyalty).to.be.equal(3 * 100);
      loyaltyList = await justFriends.getListLoyalty(creator.address, periodId);
      expect(loyaltyList.length).to.be.equal(3);
      expect(loyaltyList[0]).to.be.equal(user_1.address);
      expect(loyaltyList[1]).to.be.equal(user_2.address);
      expect(loyaltyList[2]).to.be.equal(user_3.address);
      expect(await justFriends.balanceOf(user_3.address, contentId.toString())).to.be.equal(100);

      buyPrice = await justFriends.getBuyPrice(contentHash, 1000);
      console.log("🚀 ~ file: Test.ts:150 ~ buyPrice:", ethers.formatEther(buyPrice));
      const buyTx5 = await justFriends.connect(user_4).buyContentAccess(contentHash, "1000", { value: buyPrice });
      await expect(buyTx5).to.be.emit(justFriends, "AccessPurchased").withArgs(contentHash, user_4.address, 1000, buyPrice);
      expect((await justFriends.loyalFanRecords(user_4.address, creator.address, periodId)).loyalty).to.be.equal(3 * 1000);
      loyaltyList = await justFriends.getListLoyalty(creator.address, periodId);
      expect(loyaltyList.length).to.be.equal(3);
      expect(loyaltyList[0]).to.be.equal(user_1.address);
      expect(loyaltyList[1]).to.be.equal(user_4.address);
      expect(loyaltyList[2]).to.be.equal(user_3.address);
      expect(await justFriends.balanceOf(user_4.address, contentId.toString())).to.be.equal(1000);
      const periodData = await justFriends.periodList(creator.address, periodId);
      expect(periodData.revenue).to.be.greaterThan(1);

      mine(periodBlock);
      const currentPeriodId = periodId + 1;
      buyPrice = await justFriends.getBuyPrice(contentHash, 1);
      console.log("🚀 ~ file: Test.ts:150 ~ buyPrice:", ethers.formatEther(buyPrice));
      const buyTx6 = await justFriends.connect(user_4).buyContentAccess(contentHash, "1", { value: buyPrice });
      await expect(buyTx6).to.be.emit(justFriends, "AccessPurchased").withArgs(contentHash, user_4.address, 1, buyPrice);
      expect((await justFriends.loyalFanRecords(user_4.address, creator.address, currentPeriodId)).loyalty).to.be.equal(3);
      const lastPeriodData = await justFriends.periodList(creator.address, periodId);
      expect(lastPeriodData.isClose).to.be.equal(true);
      loyaltyList = await justFriends.getListLoyalty(creator.address, currentPeriodId);
      expect(loyaltyList.length).to.be.equal(1);
      expect(loyaltyList[0]).to.be.equal(user_4.address);
      expect(await justFriends.balanceOf(user_4.address, contentId.toString())).to.be.equal(1001);
    });
    it("Should succeed to sell vote", async function () {
      let buyPrice = await justFriends.getBuyPrice(contentHash, 1);
      const buyTx = await justFriends.connect(user_1).buyContentAccess(contentHash, "1", { value: buyPrice });
      const balanceBefore = await ethers.provider.getBalance(user_1.address);
      await expect(buyTx).to.be.emit(justFriends, "AccessPurchased").withArgs(contentHash, user_1.address, 1, buyPrice);
      expect((await justFriends.loyalFanRecords(user_1.address, creator.address, periodId)).loyalty).to.be.equal(3);
      let loyaltyList = await justFriends.getListLoyalty(creator.address, periodId);
      expect(loyaltyList.length).to.be.equal(1);
      expect(loyaltyList[0]).to.be.equal(user_1.address);
      expect(await justFriends.balanceOf(user_1.address, contentId.toString())).to.be.equal(1);
      let sellTx = await justFriends.connect(user_1).sellContentAccess(contentHash, 1);
      await expect(sellTx).to.be.emit(justFriends, "AccessSold");
      const balanceAfter = await ethers.provider.getBalance(user_1.address);
      expect(balanceAfter).to.be.greaterThan(balanceBefore);
    });
    it("Should fail to sell vote if caller doesn't own it", async function () {
      let buyPrice = await justFriends.getBuyPrice(contentHash, 1);
      await justFriends.connect(user_1).buyContentAccess(contentHash, "1", { value: buyPrice });
      let sellTx = justFriends.connect(user_1).sellContentAccess(contentHash, 1);
      expect(sellTx).to.be.revertedWithCustomError(justFriends, "InsufficientAccess");
    });
  });
});
