import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
// @ts-ignore
import { ethers } from "hardhat";
import {
  MINIMAL_FORWARDER,
  ROYALTY_SPLITTER,
  developmentChains,
  networkConfig,
} from "../helper-hardhat-config";
import verify, {
  readContractAddress,
  writeContractAddress,
} from "../helper-functions";

const deployRevenueSplitter: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre;
  const { deployer } = await getNamedAccounts();
  const { deploy, log } = deployments;

  log(`\t Deploying Revenue splitter contract`);

  const minimalForwarder = await ethers.getContractAt(
    MINIMAL_FORWARDER,
    await readContractAddress(MINIMAL_FORWARDER)
  );
  const royaltySplitter = await deploy(ROYALTY_SPLITTER, {
    from: deployer,
    args: [minimalForwarder.address],
    log: true,
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  });

  log(`\t Revenue splitter contract is deployed at ${royaltySplitter.address}`);

  if (
    !developmentChains.includes(network.name) &&
    networkConfig[network.name].apiKey
  ) {
    await verify(royaltySplitter.address, [minimalForwarder.address]);
  }

  await writeContractAddress(ROYALTY_SPLITTER, royaltySplitter.address);
};

export default deployRevenueSplitter;
deployRevenueSplitter.tags = ["all", "splitter"];
