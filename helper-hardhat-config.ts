import { ethers } from "hardhat";
import { Config } from "./typechain-types/contracts/MembershipCollection";
import { BigNumber } from "ethers";

export interface networkConfigItem {
  blockConfirmations?: number;
  treasuryAddress?: string;
  apiKey?: string;
}

export interface networkConfigInfo {
  [key: string]: networkConfigItem;
}

export const DEFAULT_TREASURY = "0xc946076ef04CCbaE8E75679ec2a7278490F13960";

export const networkConfig: networkConfigInfo = {
  hardhat: {},
  localhost: {},
  goerli: {
    blockConfirmations: 2,
    treasuryAddress: DEFAULT_TREASURY,
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  mumbai: {
    blockConfirmations: 2,
    treasuryAddress: DEFAULT_TREASURY,
    apiKey: process.env.POLYGONSCAN_API_KEY,
  },
  binance: {
    blockConfirmations: 2,
    treasuryAddress: DEFAULT_TREASURY,
    apiKey: process.env.BSCSCAN_API_KEY,
  },
};

export const ETH_EMISSION_RATE = 13.2;

export const developmentChains = ["hardhat", "localhost"];
export const deploymentFile = "contracts.json";
export const ADDRESS_ZERO = ethers.constants.AddressZero;
export const NUMERICAL_CONSTANT = 1e18;
export const TOKEN_VALIDITY = 3600; // This value is used only for testing
export const TOTAL_BLOCKS_PER_HOUR = Math.ceil(
  TOKEN_VALIDITY / ETH_EMISSION_RATE
);

// Contract Names here
export const MINIMAL_FORWARDER = "MinimalForwarder";
export const GENERIC_PROXY_FACTORY = "GenericProxyFactory";
export const DAO_CONTRACT = "CreatorDAO";
export const PRODUCT_NFT_CONTRACT = "ERC721Collection";
export const MEMBERSHIP_NFT_CONTRACT = "MembershipCollection";
export const ROYALTY_SPLITTER = "RoyaltySplitter";

export const ERC721_CONTRACT = "ERC721Contract";
export const ERC721_PROXY_MANAGER = "ERC721ProxyManager";

export const ERC1155_CONTRACT = "ERC1155Contract";
export const ERC1155_PROXY_MANAGER = "ERC1155ProxyManager";

export const PLATFORM_FEE_MANAGER = "PlatformFeeManager";

// Configuration for membership collection tiers
export const TIERS: Config.TierConfigStruct[] = [
  {
    tierId: "Basic",
    floorPrice: ethers.utils.parseEther("1"),
    totalSupply: 10,
  },
  {
    tierId: "Advanced",
    floorPrice: ethers.utils.parseEther("2"),
    totalSupply: 100,
  },
  {
    tierId: "Pro",
    floorPrice: ethers.utils.parseEther("3"),
    totalSupply: 103,
  },
];

export const ERC721Options = {
  metadata: {
    defaultAdmin: "",
    name: "NFT Collection",
    symbol: "NFC",
    contractURI: "URIofcontract",
    baseURI: "https://decir.pinata.cloud/aldjflajk/ipfs/", //
    royaltyRecipient: DEFAULT_TREASURY,
    royaltyBps: 100,
    primarySaleRecipient: DEFAULT_TREASURY,
    floorPrice: ethers.utils.parseEther("0.0001"),
    maxSupply: 100,
    initialSupply: 10,
    platformFeeManager: "",
    isSoulbound: true,
    validity: 0,
  },
  masterCopy: "",
};

export const ERC1155Options = {
  metadata: {
    defaultAdmin: "",
    name: "Name",
    symbol: "SYS",
    contractURI: "URIofcontract",
    baseURI: "Tokenbaseuri",
    royaltyRecipient: DEFAULT_TREASURY,
    royaltyBps: 100,
    primarySaleRecipient: DEFAULT_TREASURY,
    initialSupply: 0,
    initialPrices: [ethers.utils.parseEther("0.0001")],
    initialMaxSupplies: [0],
    platformFeeManager: "",
    isSoulbound: true,
    validity: 0,
  },
  masterCopy: "",
};
