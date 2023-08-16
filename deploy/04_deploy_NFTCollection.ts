import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
// @ts-ignore
import { ethers } from "hardhat";
import {
  MINIMAL_FORWARDER,
  PRODUCT_NFT_CONTRACT,
  developmentChains,
  networkConfig,
} from "../helper-hardhat-config";
import verify, {
  readContractAddress,
  writeContractAddress,
} from "../helper-functions";

const deployProductNFT: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre;
  const { deployer } = await getNamedAccounts();
  const { get, deploy, log } = deployments;

  log(`\t Deploying Product NFT contract`);

  const minimalForwarder = await ethers.getContractAt(
    MINIMAL_FORWARDER,
    await readContractAddress(MINIMAL_FORWARDER)
  );

  const nftContract = await deploy(PRODUCT_NFT_CONTRACT, {
    from: deployer,
    args: [minimalForwarder.address],
    log: true,
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  });

  log(`\t Product NFT contract is deployed at ${nftContract.address}`);

  if (
    !developmentChains.includes(network.name) &&
    networkConfig[network.name].apiKey
  ) {
    await verify(nftContract.address, [minimalForwarder.address]);
  }

  await writeContractAddress(PRODUCT_NFT_CONTRACT, nftContract.address);
};

export default deployProductNFT;
deployProductNFT.tags = ["all", "pnft"];
