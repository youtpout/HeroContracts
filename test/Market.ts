import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { GameManager, GameManagerV2, GameManagerV2__factory, HeroPoints, HeroPotion, HeroSpell, Marketplace, MarketplaceV2 } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { PromiseOrValue } from "../typechain-types/common";
import { BigNumberish, BytesLike } from "ethers";
import { gameManagerv2Sol } from "../typechain-types/contracts";

describe("Market", function () {
  var tokenContract: HeroPoints,
    itemContract: HeroPotion,
    spellContract: HeroSpell,
    shopContract: Marketplace | MarketplaceV2,
    gameContract: GameManager | GameManagerV2;

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

    const BoxV2 = await ethers.getContractFactory("MarketplaceV2");
    shopContract = await upgrades.upgradeProxy(shopContract.address, BoxV2) as MarketplaceV2;
    console.log("Marketplace upgraded");

    const ContractGame = await ethers.getContractFactory("GameManager");
    gameContract = await upgrades.deployProxy(ContractGame) as GameManager;
    await gameContract.deployed();

    const gameV2 = await ethers.getContractFactory("GameManagerV2");
    gameContract = await upgrades.upgradeProxy(gameContract.address, gameV2) as GameManagerV2;
    console.log("GameManager upgraded");

    let masterRole = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MASTER_ROLE"));
    let minterRole = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE"));
    await shopContract.grantRole(masterRole, gameContract.address);
    await shopContract.addTokenAccepted(tokenContract.address);

    await spellContract.addMarketAddress(gameContract.address);
    await spellContract.addMarketAddress(shopContract.address);
    await spellContract.grantRole(minterRole, gameContract.address);

    await itemContract.addMarketAddress(gameContract.address);
    await itemContract.addMarketAddress(shopContract.address);
    await itemContract.grantRole(minterRole, gameContract.address);

    await tokenContract.addMarketAddress(gameContract.address);
    await tokenContract.addMarketAddress(shopContract.address);
    await tokenContract.grantRole(minterRole, gameContract.address);
  });


  describe("Test shopping", function () {
    it("Should create a order", async function () {
      let mint = await itemContract.mint(dev2.address, 1, 10, []);
      await mint.wait();

      let itemAmount = await itemContract.balanceOf(dev2.address, 1);
      expect(itemAmount).equal(10);

      // sell for 3 hero points by unit, accept hero point token, authorize buy at unit
      let threeToken = ethers.utils.parseEther("3");
      let data = [threeToken, tokenContract.address, dev2.address, true];
      let dataTransfer = ethers.utils.defaultAbiCoder.encode(["uint256", "address", "address", "bool"], data);


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

  describe("Test direct sell from minting", function () {
    it("Should create a order", async function () {
      let itemAmount = await itemContract.balanceOf(dev2.address, 1);
      expect(itemAmount).equal(0);

      // sell for 3 hero points by unit, accept hero point token, authorize buy at unit
      let threeToken = ethers.utils.parseEther("3");
      let data = [threeToken, tokenContract.address, dev2.address, true];
      let dataTransfer = ethers.utils.defaultAbiCoder.encode(["uint256", "address", "address", "bool"], data);

      // direct mint to the shop with seller infos
      let action: GameManager.ActionStruct = {
        actionType: 1,
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

  describe("Test mint/sell/buy/cancel in one action", function () {
    it("Should create a order", async function () {
      let itemAmount = await itemContract.balanceOf(dev2.address, 1);
      expect(itemAmount).equal(0);

      // sell for 3 hero points by unit, accept hero point token, authorize buy at unit
      let threeToken = ethers.utils.parseEther("3");
      let data = [threeToken, tokenContract.address, dev2.address, true];
      let dataTransfer = ethers.utils.defaultAbiCoder.encode(["uint256", "address", "address", "bool"], data);

      // direct mint to the shop with seller infos
      let actionmintSell: GameManager.ActionStruct = {
        actionType: 1,
        contractType: 2,
        contractAddress: itemContract.address,
        recipient: shopContract.address,
        spender: dev2.address,
        amount: 5,
        tokenId: 1,
        data: dataTransfer
      };

      // mint token for the buyer
      let actionMint: GameManager.ActionStruct = {
        actionType: 1,
        contractType: 0,
        contractAddress: tokenContract.address,
        data: [],
        recipient: dev3.address,
        spender: shopContract.address,
        amount: ethers.utils.parseEther("10"),
        tokenId: 0,
      };

      let sixTokens = threeToken.mul(2);
      var buyCall = shopContract.interface.encodeFunctionData("buyOrder", [dev3.address, 1, sixTokens, 2]);
      // cancel the order
      let actionBuy: GameManager.ActionStruct = {
        actionType: 3,
        contractType: 3,
        contractAddress: shopContract.address,
        data: buyCall,
        recipient: shopContract.address,
        spender: shopContract.address,
        amount: 0,
        tokenId: 0,
      };

      // burn 1 token received by the buyer
      let actionBurn: GameManager.ActionStruct = {
        actionType: 0,
        contractType: 2,
        contractAddress: itemContract.address,
        data: [],
        recipient: shopContract.address,
        spender: dev3.address,
        amount: 1,
        tokenId: 1,
      };

      var cancelCall = shopContract.interface.encodeFunctionData("cancelOrder", [1]);

      // cancel the order
      let actionCancel: GameManager.ActionStruct = {
        actionType: 3,
        contractType: 3,
        contractAddress: shopContract.address,
        data: cancelCall,
        recipient: shopContract.address,
        spender: shopContract.address,
        amount: 0,
        tokenId: 0,
      };

      // will mint nft, mint token, buy nft, burn token
      let execBuy = await gameContract.executeActions([actionmintSell, actionMint, actionBuy, actionBurn, actionCancel]);
      await execBuy.wait();

      let itemBuyer = await itemContract.balanceOf(dev3.address, 1);
      expect(itemBuyer).equal(1);

      let balandeDev2 = await tokenContract.balanceOf(dev2.address);
      let amountSubtax = sixTokens.sub(sixTokens.mul(5).div(100));
      expect(balandeDev2).equal(amountSubtax);

      let balanceBank = await tokenContract.balanceOf(owner.address);
      expect(balanceBank).equal(sixTokens.mul(5).div(100));

      // retrieve the 3 items
      itemAmount = await itemContract.balanceOf(dev2.address, 1);
      expect(itemAmount).equal(3);

    });

  });

  describe("Test mint buy burn", function () {
    it("Should create a order", async function () {
      let itemAmount = await itemContract.balanceOf(dev2.address, 1);
      expect(itemAmount).equal(0);

      // sell for 3 hero points by unit, accept hero point token, authorize buy at unit
      let threeToken = ethers.utils.parseEther("3");
      let data = [threeToken, tokenContract.address, dev2.address, true];
      let dataTransfer = ethers.utils.defaultAbiCoder.encode(["uint256", "address", "address", "bool"], data);

      // direct mint to the shop with seller infos
      let action: GameManager.ActionStruct = {
        actionType: 1,
        contractType: 2,
        contractAddress: itemContract.address,
        recipient: shopContract.address,
        spender: dev2.address,
        amount: 5,
        tokenId: 1,
        data: dataTransfer
      }

      // will create the order
      let exec = await gameContract.executeActions([action]);
      await exec.wait();

      let order = await shopContract.orders(1);
      expect(order.currentAmount).equal(5);

      // mint token for the buyer
      let tenTokens = ethers.utils.parseEther("10");
      let mintToken = await tokenContract.mint(dev3.address, tenTokens);
      await mintToken.wait();
      let balanceToken = await tokenContract.balanceOf(dev3.address);
      expect(balanceToken).equal(tenTokens);

      let sixTokens = threeToken.mul(2);
      var buyCall = shopContract.interface.encodeFunctionData("buyOrder", [dev3.address, order.id, sixTokens, 2]);
      // cancel the order
      let actionBuy: GameManager.ActionStruct = {
        actionType: 3,
        contractType: 3,
        contractAddress: shopContract.address,
        data: buyCall,
        recipient: shopContract.address,
        spender: shopContract.address,
        amount: 0,
        tokenId: 0,
      };

      // will buy
      let execBuy = await gameContract.executeActions([actionBuy]);
      await execBuy.wait();

      let itemBuyer = await itemContract.balanceOf(dev3.address, 1);
      expect(itemBuyer).equal(2);

      let balandeDev2 = await tokenContract.balanceOf(dev2.address);
      let amountSubtax = sixTokens.sub(sixTokens.mul(5).div(100));
      expect(balandeDev2).equal(amountSubtax);

      let balanceBank = await tokenContract.balanceOf(owner.address);
      expect(balanceBank).equal(sixTokens.mul(5).div(100));

      var cancelCall = shopContract.interface.encodeFunctionData("cancelOrder", [order.id]);

      // cancel the order
      let actionCancel: GameManager.ActionStruct = {
        actionType: 3,
        contractType: 3,
        contractAddress: shopContract.address,
        data: cancelCall,
        recipient: shopContract.address,
        spender: shopContract.address,
        amount: 0,
        tokenId: 0,
      };

      // will cancel the order
      let exec2 = await gameContract.executeActions([actionCancel]);
      await exec2.wait();

      // retrieve the 3 items
      itemAmount = await itemContract.balanceOf(dev2.address, 1);
      expect(itemAmount).equal(3);

    });

  });
});
