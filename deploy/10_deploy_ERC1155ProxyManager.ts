import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
// @ts-ignore
import { ethers } from "hardhat";
import {
  developmentChains,
  networkConfig,
  ERC1155_PROXY_MANAGER,
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

  log(`\t Deploying ${ERC1155_PROXY_MANAGER} contract`);

  //   ! Minimal forwarder is not deployed for now
  //   const minimalForwarder = await ethers.getContractAt(
  //     MINIMAL_FORWARDER,
  //     await readContractAddress(MINIMAL_FORWARDER)
  //   );

  const ERC1155Proxy = await deploy(ERC1155_PROXY_MANAGER, {
    from: deployer,
    args: [],
    log: true,
    proxy: false,
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  });

  log(
    `\t ${ERC1155_PROXY_MANAGER} contract is deployed at ${ERC1155Proxy.address}`
  );

  if (
    !developmentChains.includes(network.name) &&
    networkConfig[network.name].apiKey
  ) {
    await verify(ERC1155Proxy.address, []);
  }

  await writeContractAddress(ERC1155_PROXY_MANAGER, ERC1155Proxy.address);
};

export default deployProductNFT;
deployProductNFT.tags = ["all", "erc1155Proxy", "v2"];
