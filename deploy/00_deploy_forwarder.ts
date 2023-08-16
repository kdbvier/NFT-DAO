import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import {
  MINIMAL_FORWARDER,
  developmentChains,
  networkConfig,
} from "../helper-hardhat-config";
import verify, { writeContractAddress } from "../helper-functions";

const deployMinimalForwarder: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments, network } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const forwarder = await deploy(MINIMAL_FORWARDER, {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
  });

  log(`\t Minimal forwarder is deployed at ${forwarder.address}`);

  if (
    !developmentChains.includes(network.name) &&
    networkConfig[network.name].apiKey
  ) {
    await verify(forwarder.address, []);
  }

  await writeContractAddress(MINIMAL_FORWARDER, forwarder.address);
};

export default deployMinimalForwarder;
deployMinimalForwarder.tags = ["all", "forwarder"];
