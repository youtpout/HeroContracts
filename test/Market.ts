import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { GameManager, HeroPoints, HeroPotion, HeroSpell, Marketplace } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { PromiseOrValue } from "../typechain-types/common";
import { BigNumberish, BytesLike } from "ethers";

describe("Market", function () {
  var tokenContract: HeroPoints,
    itemContract: HeroPotion,
    spellContract: HeroSpell,
    shopContract: Marketplace,
    gameContract: GameManager;

  var owner: SignerWithAddress,
    dev2: SignerWithAddress,
    dev3: SignerWithAddress,
    dev4: SignerWithAddress;

  beforeEach(async function () {
    [owner, dev2, dev3, dev4] = await ethers.getSigners();

    const ContractItem = await ethers.getContractFactory("HeroPotion");
    itemContract = await upgrades.deployProxy(ContractItem) as HeroPotion;
    await itemContract.deployed();

    const SpellItem = await ethers.getContractFactory("HeroSpell");
    spellContract = await upgrades.deployProxy(SpellItem) as HeroSpell;
    await spellContract.deployed();

    const ContractToken = await ethers.getContractFactory("HeroPoints");
    tokenContract = await upgrades.deployProxy(ContractToken) as HeroPoints;
    await tokenContract.deployed();

    const ContractShop = await ethers.getContractFactory("Marketplace");
    shopContract = await upgrades.deployProxy(ContractShop) as Marketplace;
    await shopContract.deployed();

    const ContractGame = await ethers.getContractFactory("GameManager");
    gameContract = await upgrades.deployProxy(ContractGame) as GameManager;
    await gameContract.deployed();

    let masterRole = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MASTER_ROLE"));
    await shopContract.grantRole(masterRole, gameContract.address);
    await shopContract.addTokenAccepted(tokenContract.address);

    await spellContract.addMarketAddress(gameContract.address);
    await spellContract.addMarketAddress(shopContract.address);

    await itemContract.addMarketAddress(gameContract.address);
    await itemContract.addMarketAddress(shopContract.address);

    await tokenContract.addMarketAddress(gameContract.address);
    await tokenContract.addMarketAddress(shopContract.address);
  });


  describe("Test shopping", function () {
    it("Should create a order", async function () {
      let mint = await itemContract.mint(dev2.address, 1, 10, []);
      await mint.wait();

      let itemAmount = await itemContract.balanceOf(dev2.address, 1);
      expect(itemAmount).equal(10);

      // sell for 3 hero points by unit, accept hero point token, authorize buy at unit
      let threeToken = ethers.utils.parseEther("3");
      let data = [threeToken, tokenContract.address, true];
      let dataTransfer = ethers.utils.defaultAbiCoder.encode(["uint256", "address", "bool"], data);


      let action: GameManager.ActionStruct = {
        actionType: 2,
        contractType: 2,
        contractAddress: itemContract.address,
        recipient: shopContract.address,
        spender: dev2.address,
        amount: 5,
        tokenId: 1,
        data: dataTransfer
      }

      console.log("gamecontract", gameContract.address);

      // will create the order
      let exec = await gameContract.executeActions([action]);
      await exec.wait();

      itemAmount = await itemContract.balanceOf(dev2.address, 1);
      expect(itemAmount).equal(5);

      let order = await shopContract.orders(1);
      expect(order.currentAmount).equal(5);

      // mint token for the buyer
      let tenTokens = ethers.utils.parseEther("10");
      let mintToken = await tokenContract.mint(dev3.address, tenTokens);
      await mintToken.wait();
      let balanceToken = await tokenContract.balanceOf(dev3.address);
      expect(balanceToken).equal(tenTokens);

      let sixTokens = threeToken.mul(2);
      let buy = await shopContract.buyOrder(dev3.address, order.id, sixTokens, 2);
      await buy.wait();

      let itemBuyer = await itemContract.balanceOf(dev3.address, 1);
      expect(itemBuyer).equal(2);

      let balandeDev2 = await tokenContract.balanceOf(dev2.address);
      let amountSubtax = sixTokens.sub(sixTokens.mul(5).div(100));
      expect(balandeDev2).equal(amountSubtax);

      let balanceBank = await tokenContract.balanceOf(owner.address);
      expect(balanceBank).equal(sixTokens.mul(5).div(100));
    });

  });

});
