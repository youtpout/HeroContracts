import { ethers, upgrades } from "hardhat";
import { MarketplaceV2 } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const proxy_market = "0x0b59005564c24fDE45287c72D64914838CC14d0E";

async function main() {
  let [owner] = await ethers.getSigners();

  const BoxV2 = await ethers.getContractFactory("MarketplaceV2");
  let shopContract = await upgrades.upgradeProxy(proxy_market, BoxV2) as MarketplaceV2;
  console.log("Marketplace upgraded", shopContract.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
