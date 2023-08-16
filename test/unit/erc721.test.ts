import {
  ERC721ProxyManager,
  ERC721Contract,
  PlatformFeeManager,
} from "../../typechain-types";
import { deployments, ethers, getNamedAccounts, network } from "hardhat";
import {
  ERC721Options,
  ERC721_CONTRACT,
  ERC721_PROXY_MANAGER,
  PLATFORM_FEE_MANAGER,
} from "../../helper-hardhat-config";
import { keccak256, toUtf8Bytes } from "ethers/lib/utils";
import { expect } from "chai";
import { moveBlock } from "../../move-blocks";
import { moveTime } from "../../move-time";
import { erc721 } from "../../typechain-types/@openzeppelin/contracts-upgradeable/token";
import { BigNumber } from "ethers";
import { platform } from "os";

// describe("ERC721 NFT Flow", async () => {
//   let proxyManager: ERC721ProxyManager;
//   let erc721Contract: ERC721Contract;
//   let platformFeeManager: PlatformFeeManager;
//   let proxyAddress: string;
//   let counter: number = 0;

//   beforeEach(async () => {
//     const { deployer } = await getNamedAccounts();
//     await deployments.fixture(["all"]);

//     proxyManager = await ethers.getContract(ERC721_PROXY_MANAGER, deployer);
//     const erc721Implementation = await ethers.getContract(ERC721_CONTRACT);

//     platformFeeManager = await ethers.getContract(PLATFORM_FEE_MANAGER);

//     ERC721Options.metadata.defaultAdmin = deployer;
//     ERC721Options.masterCopy = erc721Implementation.address;
//     ERC721Options.metadata.platformFeeManager = platformFeeManager.address;

//     ERC721Options.metadata.isSoulbound = false;

//     const factoryTx = await proxyManager.DeployERC721(ERC721Options);
//     const factoryReceipt = await factoryTx.wait(1);

//     proxyAddress =
//       factoryReceipt.events![factoryReceipt.events!.length - 1].args!.newProxy;

//     erc721Contract = await ethers.getContractAt(
//       ERC721_CONTRACT,
//       proxyAddress,
//       deployer
//     );
//   });

//   it("Should be able to set proxy default admin", async () => {
//     const { deployer } = await getNamedAccounts();
//     const owner = await erc721Contract.owner();
//     await expect(owner).to.be.equal(deployer);
//   });

//   it("Should be able to verify contract and base uri", async () => {
//     const contractURI = await erc721Contract.contractURI();
//     const baseURI = await erc721Contract.baseURI();

//     await expect(contractURI).to.be.equal(ERC721Options.metadata.contractURI);
//     await expect(baseURI).to.be.equal(ERC721Options.metadata.baseURI);
//   });

//   it("Should be able to verify royalty information", async () => {});
//   it("Should be able to verify sales information", async () => {});
//   it("Should be able to verify token based information", async () => {});

//   //  ? Finish minting with price
//   it("Should be able to mint new token", async () => {
//     const { deployer } = await getNamedAccounts();

//     let _tokenId = 0;

//     const mintTx = await erc721Contract.mint(0, {
//       value: ERC721Options.metadata.floorPrice,
//     });

//     const mintTxReceipt = await mintTx.wait(1);
//     const tokenId =
//       mintTxReceipt.events![mintTxReceipt.events!.length - 1].args!
//         .tokenIdMinted;

//     await expect(tokenId).to.be.equal(_tokenId);

//     const tokenOwner = await erc721Contract.ownerOf(0);
//     await expect(tokenOwner).to.be.equal(deployer);
//   });

//   it("Should be able to check token URI", async () => {
//     let tokenId = 0;
//     const tokenURI = await erc721Contract.tokenURI(0);
//     const baseURI = await erc721Contract.baseURI();
//     await expect(tokenURI).to.be.equal(baseURI + tokenId.toString());
//   });

//   it("Should be able to transfer nfts", async () => {
//     const { deployer, holder } = await getNamedAccounts();
//     const mintTx = await erc721Contract.mint(0, {
//       value: ERC721Options.metadata.floorPrice,
//     });

//     const mintTxReceipt = await mintTx.wait(1);
//     const tokenId =
//       mintTxReceipt.events![mintTxReceipt.events!.length - 1].args!
//         .tokenIdMinted;
//     await erc721Contract.transferFrom(deployer, holder, tokenId);
//     const newOwner = await erc721Contract.ownerOf(tokenId);
//     expect(newOwner).to.be.equal(holder);
//     // const hash = keccak256(toUtf8Bytes('TRANSFER_ROLE'));
//     // const oldstatus = await erc721Contract.hasRole(hash, deployer);
//     // expect(oldstatus).to.be.equal(false);
//     // await erc721Contract.grantRole(hash, deployer);
//     // const newstatus = await erc721Contract.hasRole(hash, deployer);
//     // expect(newstatus).to.be.equal(true);
//     // await erc721Contract.transferFrom(deployer, holder, 0);
//     // const newOwner = await erc721Contract.ownerOf(0);
//     // expect(newOwner).to.be.equal(holder);
//   });

//   it("Should be able to add new tokens", async () => {});
//   //   ? Finish minting with price
//   it("Should be able to mint newly added tokens", async () => {});
//   it("Should be an Soul-bound NFT", async () => {});
//   it("Should be an Time-bound NFT", async () => {});

//   it("Should be able to track minted token id", async () => {});

//   //   it("Should be an Soul-bound NFT", async () => {
//   //     const { deployer, holder } = await getNamedAccounts();
//   //     const tokenURI: string = "tokenURI";
//   //     const mintTokenTx = await membership.mintToCaller(
//   //       deployer,
//   //       tokenURI,
//   //       TIERS[0].tierId,
//   //       { value: TIERS[0].floorPrice }
//   //     );

//   //     const mintTokenReceipt = await mintTokenTx.wait(1);
//   //     const tokenId =
//   //       mintTokenReceipt.events![mintTokenReceipt.events!.length - 1].args!
//   //         .tokenId;

//   //     if (deployOptions.isLocked)
//   //       await expect(membership.transferFrom(deployer, holder, tokenId)).to.be
//   //         .reverted;
//   //     else {
//   //       // check before transfer
//   //       const tokenOwner = await membership.ownerOf(tokenId);
//   //       await expect(tokenOwner).to.be.equal(deployer);
//   //       const transferFromTx = await membership.transferFrom(
//   //         deployer,
//   //         holder,
//   //         tokenId
//   //       );
//   //       const transferFromReceipt = await transferFromTx.wait(1);
//   //       const transferredTokenId =
//   //         transferFromReceipt.events![transferFromReceipt.events!.length - 1]
//   //           .args!.tokenId;
//   //       await expect(transferredTokenId).to.be.equal(tokenId);
//   //     }
//   //   });

//   //   it("Should be an Time-bound NFT", async () => {
//   //     const { deployer, holder } = await getNamedAccounts();
//   //     const tokenURI: string = "tokenURI";
//   //     const mintTokenTx = await membership.mintToCaller(
//   //       deployer,
//   //       tokenURI,
//   //       TIERS[0].tierId,
//   //       { value: TIERS[0].floorPrice }
//   //     );

//   //     const mintTokenReceipt = await mintTokenTx.wait(1);
//   //     const tokenId =
//   //       mintTokenReceipt.events![mintTokenReceipt.events!.length - 1].args!
//   //         .tokenId;
//   //     const validity =
//   //       mintTokenReceipt.events![mintTokenReceipt.events!.length - 2].args!
//   //         .timeStamp;

//   //     let isValid = await membership.hasExpired(tokenId);
//   //     await expect(isValid).to.be.equal(true);
//   //     if (developmentChains.includes(network.name)) {
//   //       await moveTime(TOKEN_VALIDITY + 1);
//   //       await moveBlock(1);
//   //     }
//   //     isValid = await membership.hasExpired(tokenId);
//   //     await expect(isValid).to.be.equal(false);
//   //   });
// });
// describe("ERC721 NFT Soulbound Flow", async () => {
//   let proxyManager: ERC721ProxyManager;
//   let erc721Contract: ERC721Contract;
//   let platformFeeManager: PlatformFeeManager;
//   let proxyAddress: string;
//   let counter: number = 0;

//   beforeEach(async () => {
//     const { deployer } = await getNamedAccounts();
//     await deployments.fixture(["all"]);

//     proxyManager = await ethers.getContract(ERC721_PROXY_MANAGER, deployer);
//     const erc721Implementation = await ethers.getContract(ERC721_CONTRACT);

//     platformFeeManager = await ethers.getContract(PLATFORM_FEE_MANAGER);

//     ERC721Options.metadata.defaultAdmin = deployer;
//     ERC721Options.masterCopy = erc721Implementation.address;
//     ERC721Options.metadata.platformFeeManager = platformFeeManager.address;

//     ERC721Options.metadata.isSoulbound = true;

//     const factoryTx = await proxyManager.DeployERC721(ERC721Options);
//     const factoryReceipt = await factoryTx.wait(1);

//     proxyAddress =
//       factoryReceipt.events![factoryReceipt.events!.length - 1].args!.newProxy;

//     erc721Contract = await ethers.getContractAt(
//       ERC721_CONTRACT,
//       proxyAddress,
//       deployer
//     );
//   });

//   it("Shouldnot be able to transfer nfts", async () => {
//     const { deployer, holder } = await getNamedAccounts();
//     const mintTx = await erc721Contract.mint(0, {
//       value: ERC721Options.metadata.floorPrice,
//     });

//     const mintTxReceipt = await mintTx.wait(1);
//     const tokenId =
//       mintTxReceipt.events![mintTxReceipt.events!.length - 1].args!
//         .tokenIdMinted;
//     expect(
//       erc721Contract.transferFrom(deployer, holder, tokenId)
//     ).to.rejectedWith("restricted to TRANSFER_ROLE holders");
//   });

//   it("Should be an Soul-bound NFT", async () => {
//     const { deployer, holder } = await getNamedAccounts();
//     const mintTx = await erc721Contract.mint(0, {
//       value: ERC721Options.metadata.floorPrice,
//     });

//     const mintTxReceipt = await mintTx.wait(1);
//     const tokenId =
//       mintTxReceipt.events![mintTxReceipt.events!.length - 1].args!
//         .tokenIdMinted;
//     expect(
//       erc721Contract.transferFrom(deployer, holder, tokenId)
//     ).to.rejectedWith("restricted to TRANSFER_ROLE holders");
//     const hash = keccak256(toUtf8Bytes("TRANSFER_ROLE"));
//     const oldstatus = await erc721Contract.hasRole(hash, deployer);
//     expect(oldstatus).to.be.equal(false);
//     await erc721Contract.grantRole(hash, deployer);
//     const newstatus = await erc721Contract.hasRole(hash, deployer);
//     expect(newstatus).to.be.equal(true);
//     await erc721Contract.transferFrom(deployer, holder, tokenId);
//     const newOwner = await erc721Contract.ownerOf(tokenId);
//     expect(newOwner).to.be.equal(holder);
//   });
//   it("Should be an Time-bound NFT", async () => {});
// });

// describe("ERC721 NFT Timebound Flow", async () => {
//   let proxyManager: ERC721ProxyManager;
//   let erc721Contract: ERC721Contract;
//   let platformFeeManager: PlatformFeeManager;
//   let proxyAddress: string;
//   let counter: number = 0;

//   beforeEach(async () => {
//     const { deployer } = await getNamedAccounts();
//     await deployments.fixture(["all"]);

//     proxyManager = await ethers.getContract(ERC721_PROXY_MANAGER, deployer);
//     const erc721Implementation = await ethers.getContract(ERC721_CONTRACT);

//     platformFeeManager = await ethers.getContract(PLATFORM_FEE_MANAGER);

//     ERC721Options.metadata.defaultAdmin = deployer;
//     ERC721Options.masterCopy = erc721Implementation.address;
//     ERC721Options.metadata.platformFeeManager = platformFeeManager.address;

//     ERC721Options.metadata.isSoulbound = false;
//     ERC721Options.metadata.validity = 10;

//     const factoryTx = await proxyManager.DeployERC721(ERC721Options);
//     const factoryReceipt = await factoryTx.wait(1);

//     proxyAddress =
//       factoryReceipt.events![factoryReceipt.events!.length - 1].args!.newProxy;

//     erc721Contract = await ethers.getContractAt(
//       ERC721_CONTRACT,
//       proxyAddress,
//       deployer
//     );
//   });

//   it("Shouldnot be able to transfer nfts after bounding period", async () => {
//     const { deployer, holder } = await getNamedAccounts();
//     const isTimeBound = await erc721Contract.isTimebound();
//     const mintTx = await erc721Contract.mint(0, {
//       value: ERC721Options.metadata.floorPrice,
//     });

//     const mintTxReceipt = await mintTx.wait(1);
//     const tokenId =
//       mintTxReceipt.events![mintTxReceipt.events!.length - 1].args!
//         .tokenIdMinted;
//     await new Promise((resolve) => setTimeout(resolve, 20000));
//     expect(
//       erc721Contract.transferFrom(deployer, holder, tokenId)
//     ).to.rejectedWith("Timebound Period is already expired.");
//   });
// });
