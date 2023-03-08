import { ethers, upgrades } from "hardhat";
import { GameManager, HeroPoints, HeroPotion, HeroSpell, Marketplace } from "../typechain-types";
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

  const ContractShop = await ethers.getContractFactory("Marketplace");
  const shopContract = await upgrades.deployProxy(ContractShop) as Marketplace;
  await shopContract.deployed();
  console.log("marketplace", shopContract.address);

  const ContractGame = await ethers.getContractFactory("GameManager");
  const gameContract = await upgrades.deployProxy(ContractGame) as GameManager;
  await gameContract.deployed();
  console.log("gameManager", gameContract.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
