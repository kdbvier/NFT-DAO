import { ethers } from "hardhat";
import {
  ERC1155Options,
  ERC1155_PROXY_MANAGER,
  ERC1155_CONTRACT,
  developmentChains,
  networkConfig,
  PLATFORM_FEE_MANAGER,
} from "../helper-hardhat-config";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployProductNFT: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre;
  const { deployer } = await getNamedAccounts();
  const { get, deploy, log } = deployments;

  const proxyManager = await ethers.getContract(
    ERC1155_PROXY_MANAGER,
    deployer
  );
  const erc1155Implementation = await ethers.getContract(
    ERC1155_CONTRACT,
    deployer
  );

  const platformFeeManager = await ethers.getContract(PLATFORM_FEE_MANAGER);

  log(`\t Setting up new proxy contract...`);
  log(`\t Implementation ${erc1155Implementation.address}`);

  ERC1155Options.metadata.defaultAdmin = deployer;
  ERC1155Options.masterCopy = erc1155Implementation.address;
  ERC1155Options.metadata.platformFeeManager = platformFeeManager.address;

  const proxyTx = await proxyManager.DeployERC1155(ERC1155Options);

  const proxyReceipt = await proxyTx.wait(1);
  let proxyAddress;

  if (
    !developmentChains.includes(network.name) &&
    networkConfig[network.name].apiKey
  ) {
    proxyAddress =
      proxyReceipt.events![proxyReceipt.events!.length - 1].args!.newProxy;
  } else {
    proxyAddress =
      proxyReceipt.events![proxyReceipt.events!.length - 1].args!.newProxy;
  }

  log(`\t Proxy is created at ${proxyAddress}`);
};

export default deployProductNFT;
deployProductNFT.tags = ["all", "setup1155", "v2"];
