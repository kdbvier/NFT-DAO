import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import {
  GENERIC_PROXY_FACTORY,
  MINIMAL_FORWARDER,
  deploymentFile,
  developmentChains,
  networkConfig,
} from "../helper-hardhat-config";
// @ts-ignore
import { ethers } from "hardhat";
import verify from "../helper-functions";
import { readContractAddress, writeContractAddress } from "../helper-functions";

const deployProxyFactory: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre;
  const { deployer } = await getNamedAccounts();
  const { deploy, log } = deployments;

  log(`\t Deploying proxy factory contract`);

  //    Get minimal forwarder deployed FIXME: Can we get this from deployment file
  const minimalForwarder = await ethers.getContractAt(
    MINIMAL_FORWARDER,
    await readContractAddress(MINIMAL_FORWARDER)
  );

  const proxyFactory = await deploy(GENERIC_PROXY_FACTORY, {
    from: deployer,
    args: [minimalForwarder.address],
    log: true,
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  });

  log(`\t Generic proxy is deployed to ${proxyFactory.address}`);

  if (
    !developmentChains.includes(network.name) &&
    networkConfig[network.name].apiKey
  ) {
    await verify(proxyFactory.address, [minimalForwarder.address]);
  }

  await writeContractAddress(GENERIC_PROXY_FACTORY, proxyFactory.address);
};

export default deployProxyFactory;
deployProxyFactory.tags = ["all", "proxyFactory"];
