import { ethers, network, getNamedAccounts } from "hardhat";
import { readContractAddress } from "../../helper-functions";
import {
  MEMBERSHIP_NFT_CONTRACT,
  TOKEN_VALIDITY,
} from "../../helper-hardhat-config";

// Initialize membership contract here
export async function initialize(args: any) {
  const { deployer } = await getNamedAccounts();
  const membership = await ethers.getContractAt(
    "MembershipCollection",
    await readContractAddress(MEMBERSHIP_NFT_CONTRACT),
    deployer
  );

  console.log(`\t Initializing membership contract`);
  const initializeTx = await membership.initialize(args);

  const initializeReceipt = await initializeTx.wait(1);
  //   capture event here
}

// @ts-ignore
const arguments = {
  isLocked: true,
  collection: {
    deployConfig: {
      name: "Proxy A",
      symbol: "P_A",
      owner: "",
      masterCopy: "masterProduct.address",
    },
    runConfig: {
      baseURI: "baseURI",
      royaltiesBPS: 0,
      royaltyAddress: "zeroAddress",
      maxSupply: 100,
      floorPrice: ethers.utils.parseEther("1"),
      validity: TOKEN_VALIDITY,
    },
  },
  decirTreasury: "",
  discount: "",
  forwarder: "",
};

initialize(arguments)
  .then(() => process.exit(0))
  .catch((error) => {
    console.log(error);
    process.exit(1);
  });
