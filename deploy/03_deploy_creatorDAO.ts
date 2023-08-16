import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
// @ts-ignore
import { ethers } from "hardhat";
import {
  DAO_CONTRACT,
  MINIMAL_FORWARDER,
  developmentChains,
  networkConfig,
} from "../helper-hardhat-config";
import verify, {
  readContractAddress,
  writeContractAddress,
} from "../helper-functions";

const deployDAO: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre;
  const { deployer } = await getNamedAccounts();
  const { get, deploy, log } = deployments;

  log(`\t Deploying DAO contract`);

  //    Get minimal forwarder deployed FIXME: Can we get this from deployment file
  const minimalForwarder = await ethers.getContractAt(
    MINIMAL_FORWARDER,
    await readContractAddress(MINIMAL_FORWARDER)
  );

  const daoContract = await deploy(DAO_CONTRACT, {
    from: deployer,
    args: [minimalForwarder.address],
    log: true,
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  });

  log(`\t DAO contract is deployed at ${daoContract.address}`);

  if (
    !developmentChains.includes(network.name) &&
    networkConfig[network.name].apiKey
  ) {
    await verify(daoContract.address, [minimalForwarder.address]);
  }

  await writeContractAddress(DAO_CONTRACT, daoContract.address);
};

export default deployDAO;
deployDAO.tags = ["all", "dao"];
