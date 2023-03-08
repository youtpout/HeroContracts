import { ethers, upgrades } from "hardhat";
import { GameManager, GameManagerV2, HeroPoints, HeroPotion, HeroSpell, Marketplace, MarketplaceV2 } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

async function main() {
  let [owner] = await ethers.getSigners();

  const ContractItem = await ethers.getContractFactory("HeroPotion");
  const itemContract = await upgrades.deployProxy(ContractItem) as HeroPotion;
  await itemContract.deployed();
  console.log("potion", itemContract.address);

  const SpellItem = await ethers.getContractFactory("HeroSpell");
  const spellContract = await upgrades.deployProxy(SpellItem) as HeroSpell;
  await spellContract.deployed();
  console.log("spell", spellContract.address);

  const ContractToken = await ethers.getContractFactory("HeroPoints");
  const tokenContract = await upgrades.deployProxy(ContractToken) as HeroPoints;
  await tokenContract.deployed();
  console.log("points", tokenContract.address);

  const ContractShop = await ethers.getContractFactory("MarketplaceV2");
  const shopContract = await upgrades.deployProxy(ContractShop) as MarketplaceV2;
  await shopContract.deployed();
  console.log("marketplace", shopContract.address);

  const ContractGame = await ethers.getContractFactory("GameManagerV2");
  const gameContract = await upgrades.deployProxy(ContractGame) as GameManagerV2;
  await gameContract.deployed();
  console.log("gameManager", gameContract.address);

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

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
