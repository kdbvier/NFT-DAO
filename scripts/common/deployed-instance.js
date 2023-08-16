const { ethers } = require("hardhat");

module.exports = function getDeployedInstance(name, address) {
  return ethers.getContractFactory(name).then((f) => f.attach(address));
};
