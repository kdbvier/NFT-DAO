const {
  getCompatibilityFallbackHandlerDeployment,
  getMultiSendDeployment,
  getProxyFactoryDeployment,
  getSafeSingletonDeployment,
  getSafeL2SingletonDeployment,
  getMultiSendCallOnlyDeployment,
} = require("@gnosis.pm/safe-deployments");

const contractFactory = (hre, contractName) => {
  hre.ethers.getContractFactory(contractName);
};

const contractInstance = async (hre, deployment, address) => {
  if (!deployment) throw Error("No deployment provided");
  // TODO: use network
  const contractAddress = address || deployment.defaultAddress;
  return await hre.ethers.getContractAt(deployment.abi, contractAddress);
};

const safeSingleton = async (hre, address) =>
  contractInstance(
    hre,
    getSafeSingletonDeployment({ released: undefined }),
    address
  );

const safeL2Singleton = async (hre, address) =>
  contractInstance(
    hre,
    getSafeL2SingletonDeployment({ released: undefined }),
    address
  );

const proxyFactory = async (hre, address) =>
  contractInstance(hre, getProxyFactoryDeployment(), address);

const multiSendLib = async (hre, address) =>
  contractInstance(hre, getMultiSendDeployment(), address);

const multiSendCallOnlyLib = async (hre, address) =>
  contractInstance(hre, getMultiSendCallOnlyDeployment(), address);

const compatHandler = async (hre, address) =>
  contractInstance(hre, getCompatibilityFallbackHandlerDeployment(), address);

module.exports = {
  contractFactory,
  contractInstance,
  safeSingleton,
  safeL2Singleton,
  proxyFactory,
  multiSendLib,
  multiSendCallOnlyLib,
  compatHandler,
};
