import { ethers, upgrades } from "hardhat";
import { GameManager, HeroPoints, HeroPotion, HeroSpell, Marketplace } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

var baseNonce = 0;
var nonceOffset = 0;

async function main() {
  let [owner] = await ethers.getSigners();

  baseNonce = await ethers.provider.getTransactionCount(owner.address);
  nonceOffset = 0;

  const itemContract = await ethers.getContractAt("HeroPotion", "0xcaC7d8C63148e17Db720a778d2b13c97c86F9526");
  console.log("potion", itemContract.address);

  const spellContract = await ethers.getContractAt("HeroSpell", "0x97aEC8C8358c2419E7fD58Fa0Bd54eA20c7075F7") as HeroSpell;
  console.log("spell", spellContract.address);

  const tokenContract = await ethers.getContractAt("HeroPoints", "0xF990548068dd68481e673dbF4f6C4175C1800eC9");
  console.log("points", tokenContract.address);

  const shopContract = await ethers.getContractAt("Marketplace", "0x0b59005564c24fDE45287c72D64914838CC14d0E");
  console.log("marketplace", shopContract.address);

  const gameContract = await ethers.getContractAt("GameManager", "0xEEAa93A7B8B9f80D2C6d2189D2Bb2CEAe7899205");
  console.log("gameManager", gameContract.address);

  let masterRole = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MASTER_ROLE"));
  let minterRole = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE"));

  await shopContract.grantRole(masterRole, gameContract.address, { nonce: getNonce() });
  await shopContract.addTokenAccepted(tokenContract.address, { nonce: getNonce() });

  await spellContract.addMarketAddress(gameContract.address, { nonce: getNonce() });
  await spellContract.addMarketAddress(shopContract.address, { nonce: getNonce() });
  await spellContract.grantRole(minterRole, gameContract.address, { nonce: getNonce() });

  await itemContract.addMarketAddress(gameContract.address, { nonce: getNonce() });
  await itemContract.addMarketAddress(shopContract.address, { nonce: getNonce() });
  await itemContract.grantRole(minterRole, gameContract.address, { nonce: getNonce() });

  await tokenContract.addMarketAddress(gameContract.address, { nonce: getNonce() });
  await tokenContract.addMarketAddress(shopContract.address, { nonce: getNonce() });
  await tokenContract.grantRole(minterRole, gameContract.address, { nonce: getNonce() });
}


function getNonce() {
  return (baseNonce + (nonceOffset++));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
