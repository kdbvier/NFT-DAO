import { readFileSync, writeFileSync } from "fs";
import { run, network } from "hardhat";
import { deploymentFile } from "./helper-hardhat-config";

const verify = async (contractAddress: string, args: any[]) => {
  console.log(`\t Verifying contract at ${contractAddress}...`);
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
  } catch (e: any) {
    if (e.message.toLowerCase().includes("already verified")) {
      console.log("\t Already verified!");
    } else {
      console.log(e);
    }
  }
};

export const readContractAddress = async (contractName: string) => {
  try {
    let contracts = JSON.parse(readFileSync(deploymentFile, "utf-8"));
    const address =
      contracts[network.config.chainId!.toString()][contractName.toString()];

    return address;
  } catch (e: any) {
    console.log(e);
  }
};

export const writeContractAddress = async (
  contractName: string,
  contractAddress?: string
) => {
  try {
    let contracts = JSON.parse(readFileSync(deploymentFile, "utf-8"));
    contracts[network.config.chainId!.toString()][contractName.toString()] =
      contractAddress!;
    writeFileSync(deploymentFile, JSON.stringify(contracts));
  } catch (e: any) {
    console.log(e);
  }
};

export default verify;
