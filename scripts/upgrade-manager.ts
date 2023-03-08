import { ethers, upgrades } from "hardhat";
import { GameManagerV2, MarketplaceV2 } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const proxy_market = "0xEEAa93A7B8B9f80D2C6d2189D2Bb2CEAe7899205";

async function main() {
  let [owner] = await ethers.getSigners();

  const BoxV2 = await ethers.getContractFactory("GameManagerV2");
  let gameContract = await upgrades.upgradeProxy(proxy_market, BoxV2) as GameManagerV2;
  console.log("GameManager upgraded", gameContract.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
