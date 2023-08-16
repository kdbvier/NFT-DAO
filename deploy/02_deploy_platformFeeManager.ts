import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
// @ts-ignore
import { ethers } from "hardhat";
import {
  DEFAULT_TREASURY,
  developmentChains,
  networkConfig,
  PLATFORM_FEE_MANAGER,
} from "../helper-hardhat-config";
import verify, { writeContractAddress } from "../helper-functions";

const deployProductNFT: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre;
  const { deployer } = await getNamedAccounts();
  const { get, deploy, log } = deployments;

  log(`\t Deploying ${PLATFORM_FEE_MANAGER} contract`);

  const feeManagerProxy = await deploy(PLATFORM_FEE_MANAGER, {
    from: deployer,
    args: [],
    log: true,
    proxy: {
      execute: {
        init: {
          methodName: "initialize",
          args: [DEFAULT_TREASURY],
        },
      },
    },

    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  });

  log(
    `\t ${PLATFORM_FEE_MANAGER} contract is deployed at ${feeManagerProxy.implementation}`
  );

  if (
    !developmentChains.includes(network.name) &&
    networkConfig[network.name].apiKey
  ) {
    // ! verify implementation here
    await verify(feeManagerProxy.implementation || "", []);
  }

  await writeContractAddress(PLATFORM_FEE_MANAGER, feeManagerProxy.address);
};

export default deployProductNFT;
// Remove erc721
deployProductNFT.tags = ["all", "v2", "feeManager"];
