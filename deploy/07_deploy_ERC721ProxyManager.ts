import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
// @ts-ignore
import { ethers } from "hardhat";
import {
  developmentChains,
  networkConfig,
  ERC721_PROXY_MANAGER,
  ERC721Options,
  ERC721_CONTRACT,
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

  log(`\t Deploying ${ERC721_PROXY_MANAGER} contract`);

  //   ! Minimal forwarder is not deployed for now
  //   const minimalForwarder = await ethers.getContractAt(
  //     MINIMAL_FORWARDER,
  //     await readContractAddress(MINIMAL_FORWARDER)
  //   );

  const ERC721Proxy = await deploy(ERC721_PROXY_MANAGER, {
    from: deployer,
    args: [],
    log: true,
    proxy: false,
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  });

  log(
    `\t ${ERC721_PROXY_MANAGER} contract is deployed at ${ERC721Proxy.address}`
  );

  if (
    !developmentChains.includes(network.name) &&
    networkConfig[network.name].apiKey
  ) {
    await verify(ERC721Proxy.address, []);
  }

  await writeContractAddress(ERC721_PROXY_MANAGER, ERC721Proxy.address);
};

export default deployProductNFT;
deployProductNFT.tags = ["all", "erc721Proxy", "v2"];
