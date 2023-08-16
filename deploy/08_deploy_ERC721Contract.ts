import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
// @ts-ignore
import { ethers } from "hardhat";
import {
  MINIMAL_FORWARDER,
  ERC721_CONTRACT,
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

  log(`\t Deploying ${ERC721_CONTRACT} contract`);

  //   ! Minimal forwarder is not deployed for now
  //   const minimalForwarder = await ethers.getContractAt(
  //     MINIMAL_FORWARDER,
  //     await readContractAddress(MINIMAL_FORWARDER)
  //   );

  const nftContract = await deploy(ERC721_CONTRACT, {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  });

  log(`\t ${ERC721_CONTRACT} contract is deployed at ${nftContract.address}`);

  if (
    !developmentChains.includes(network.name) &&
    networkConfig[network.name].apiKey
  ) {
    await verify(nftContract.address, []);
  }

  await writeContractAddress(ERC721_CONTRACT, nftContract.address);
};

export default deployProductNFT;
deployProductNFT.tags = ["all", "v2", "erc721v2"];
