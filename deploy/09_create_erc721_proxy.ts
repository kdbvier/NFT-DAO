import { ethers } from "hardhat";
import {
  ERC721Options,
  ERC721_CONTRACT,
  ERC721_PROXY_MANAGER,
  PLATFORM_FEE_MANAGER,
  developmentChains,
  networkConfig,
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

  const proxyManager = await ethers.getContract(ERC721_PROXY_MANAGER, deployer);
  const feeManagerProxy = await ethers.getContract(
    PLATFORM_FEE_MANAGER,
    deployer
  );
  const erc721Implementation = await ethers.getContract(
    ERC721_CONTRACT,
    deployer
  );

  log(`\t Setting up new proxy contract...`);
  log(`\t ERC721 Implementation ${erc721Implementation.address}`);

  ERC721Options.metadata.defaultAdmin = deployer;
  ERC721Options.masterCopy = erc721Implementation.address;
  ERC721Options.metadata.platformFeeManager = feeManagerProxy.address;

  log(ERC721Options);

  const proxyTx = await proxyManager.DeployERC721(ERC721Options);
  const proxyReceipt = await proxyTx.wait(1);
  let proxyAddress;
  proxyAddress =
    proxyReceipt.events![proxyReceipt.events!.length - 1].args!.newProxy;

  log(`\t Proxy is created at ${proxyAddress}`);
};

export default deployProductNFT;
deployProductNFT.tags = ["all", "setup721", "v2"];
