import { time, loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("JustFriends", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deploy() {
    // Contracts are deployed using the first signer/account by default
    const protocolFeePercentBase = 5;
    const creatorFeePercentBase = 5;
    const extraFeePercentBase = 3;
    const loyalFeePercentBase = 1;
    const [creator, user_1, user_2, protocolFeeDestination] = await ethers.getSigners();
    const contentHash = ethers.keccak256(ethers.randomBytes(42));
    const startedPrice = 0.01;
    const freePrice = 0;

    const JustFriendsContract = await ethers.getContractFactory("JustFriends");
    const justFriendsInstance = await JustFriendsContract.deploy(
      protocolFeeDestination,
      protocolFeePercentBase,
      creatorFeePercentBase,
      extraFeePercentBase,
      loyalFeePercentBase
    );

    return {
      justFriendsInstance,
      creator,
      user_1,
      user_2,
      protocolFeeDestination,
      contentHash,
      startedPrice,
      freePrice,
      protocolFeePercentBase,
      creatorFeePercentBase,
    };
  }

  describe("Test", function () {
    it("Should register successfully", async function () {
      const { justFriendsInstance, creator } = await deploy();
      const [walletAddress, , , ,] = await justFriendsInstance.getCreatorInfo(creator);

      expect(walletAddress).to.be.equals(creator.address);
    });

    it("Should post a paid content successfully", async function () {
      const { justFriendsInstance, creator, contentHash, startedPrice } = await deploy();
      const price = ethers.parseEther(startedPrice.toString());

      await expect(justFriendsInstance.postContent(contentHash, price, true))
        .to.be.emit(justFriendsInstance, "ContentCreated")
        .withArgs(contentHash, creator.address, price, true);
    });

    it("Should post a free content successfully", async function () {
      const { justFriendsInstance, creator, contentHash, freePrice } = await deploy();

      await expect(justFriendsInstance.postContent(contentHash, freePrice, false))
        .to.be.emit(justFriendsInstance, "ContentCreated")
        .withArgs(contentHash, creator.address, freePrice, false);
    });
  });

  it("Should purchase a paid content successfully", async function () {
    const { justFriendsInstance, creator, contentHash, startedPrice, user_1, protocolFeePercentBase, creatorFeePercentBase } = await deploy();
    let result = 0;
    for (let i = 1; i <= 5; i++) {
      result += Math.pow(i, 2);
    }

    const price = (startedPrice * result) / 10000;
    const totalPrice = price + (price * protocolFeePercentBase) / 100 + (price * creatorFeePercentBase) / 100;

    await justFriendsInstance.connect(creator).postContent(contentHash, ethers.parseEther(startedPrice.toString()), true);
    await justFriendsInstance.connect(creator).buyContentAccess(contentHash, 1, { value: 0 });
    await expect(
      await justFriendsInstance.connect(user_1).buyContentAccess(contentHash, 5, {
        value: ethers.parseEther(totalPrice.toString()),
      })
    )
      .to.be.emit(justFriendsInstance, "AccessPurchased")
      .withArgs(contentHash, user_1.address, 5, ethers.parseEther(price.toString()));
  });

  it("Should sell a paid content successfully", async function () {
    const { justFriendsInstance, creator, contentHash, startedPrice, user_1, user_2, protocolFeePercentBase, creatorFeePercentBase } = await deploy();
    let expo_1 = 1 + 4 + 9;
    let expo_2 = 16 + 25;

    const price_1 = (startedPrice * expo_1) / 10000;
    const totalPrice_1 = price_1 + (price_1 * protocolFeePercentBase) / 100 + (price_1 * creatorFeePercentBase) / 100;

    const price_2 = (startedPrice * expo_2) / 10000;
    const totalPrice_2 = (price_2 * (100 + protocolFeePercentBase + creatorFeePercentBase)) / 100;

    const sellPrice = (startedPrice * 25) / 10000;
    const totalRevenue = sellPrice - (sellPrice * protocolFeePercentBase) / 100 - (sellPrice * creatorFeePercentBase) / 100;

    await justFriendsInstance.connect(creator).postContent(contentHash, ethers.parseEther(startedPrice.toString()), true);
    await justFriendsInstance.connect(creator).buyContentAccess(contentHash, 1, { value: 0 });
    await justFriendsInstance.connect(user_1).buyContentAccess(contentHash, 3, {
      value: ethers.parseEther(totalPrice_1.toString()),
    });
    await justFriendsInstance.connect(user_2).buyContentAccess(contentHash, 2, {
      value: ethers.parseEther(totalPrice_2.toString()),
    });
    await expect(await justFriendsInstance.connect(user_1).sellContentAccess(contentHash, 1))
      .to.be.emit(justFriendsInstance, "AccessSold")
      .withArgs(contentHash, user_1.address, 1, ethers.parseEther(totalRevenue.toString()));
  });
});
