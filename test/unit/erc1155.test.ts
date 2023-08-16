import { toUtf8Bytes, keccak256 } from "ethers/lib/utils";
import {
  ERC1155ProxyManager,
  ERC1155Contract,
  PlatformFeeManager,
} from "../../typechain-types";
import { deployments, ethers, getNamedAccounts, network } from "hardhat";
import {
  ERC1155Options,
  ERC1155_CONTRACT,
  ERC1155_PROXY_MANAGER,
  PLATFORM_FEE_MANAGER,
} from "../../helper-hardhat-config";
import { expect } from "chai";
import { moveBlock } from "../../move-blocks";
import { moveTime } from "../../move-time";
import { BigNumber } from "ethers";
import { privateEncrypt } from "crypto";

describe("ERC1155 Collection general contract tests", async () => {
  let proxyManager: ERC1155ProxyManager;
  let erc1155Contract: ERC1155Contract;
  let proxyAddress: string;
  let counter: number = 0;
  let platformFeeManager: PlatformFeeManager;

  beforeEach(async () => {
    const { deployer } = await getNamedAccounts();
    await deployments.fixture(["all"]);

    proxyManager = await ethers.getContract(ERC1155_PROXY_MANAGER, deployer);
    const ERC1155Implementation = await ethers.getContract(ERC1155_CONTRACT);
    platformFeeManager = await ethers.getContract(PLATFORM_FEE_MANAGER);
    ERC1155Options.metadata.defaultAdmin = deployer;
    ERC1155Options.masterCopy = ERC1155Implementation.address;
    ERC1155Options.metadata.isSoulbound = false;
    ERC1155Options.metadata.validity = 0;
    ERC1155Options.metadata.initialSupply = 3;
    ERC1155Options.metadata.initialMaxSupplies = [10, 20, 30];
    ERC1155Options.metadata.platformFeeManager = platformFeeManager.address;
    ERC1155Options.metadata.initialPrices = [
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.2"),
      ethers.utils.parseEther("0.3"),
    ];

    const factoryTx = await proxyManager.DeployERC1155(ERC1155Options);
    const factoryReceipt = await factoryTx.wait(1);

    proxyAddress =
      factoryReceipt.events![factoryReceipt.events!.length - 1].args!.newProxy;

    erc1155Contract = await ethers.getContractAt(
      ERC1155_CONTRACT,
      proxyAddress,
      deployer
    );
  });

  it("Should be able to set proxy default admin", async () => {
    const { deployer } = await getNamedAccounts();
    const owner = await erc1155Contract.owner();
    await expect(owner).to.be.equal(deployer);
  });

  it("Should be able to verify contract and base uri", async () => {
    const contractURI = await erc1155Contract.contractURI();
    const baseURI = await erc1155Contract.baseURI();

    await expect(contractURI).to.be.equal(ERC1155Options.metadata.contractURI);
    await expect(baseURI).to.be.equal(ERC1155Options.metadata.baseURI);
  });

  it("Should be able to verify royalty information", async () => {});
  it("Should be able to verify sales information", async () => {});
  it("Should be able to verify token based information", async () => {});

  it("Should be able to add new tokens", async () => {
    const { deployer } = await getNamedAccounts();
    let price = await ethers.utils.parseEther("1");
    let uri = "URI of token";
    let totalSupply = 100;

    const newTokenTx = await erc1155Contract.addNewToken(
      price,
      uri,
      totalSupply
    );

    const newTokenReceipt = await newTokenTx.wait(1);
    const tokenId =
      newTokenReceipt.events![newTokenReceipt.events!.length - 1].args!.tokenId;
    await expect(tokenId).to.be.equal(
      ERC1155Options.metadata.initialSupply + 1
    );

    await expect(await erc1155Contract.tokenURI(tokenId)).to.be.equal(uri);
  });
  it("Should be able to mint new token", async () => {
    const { deployer } = await getNamedAccounts();
    expect(erc1155Contract.mint(0, 1)).to.rejectedWith("Invalid token id");
    let price = await ethers.utils.parseEther("0.1");
    let uri = "URI of token";
    let totalSupply = 10;
    const newTokenTx = await erc1155Contract.addNewToken(
      price,
      uri,
      totalSupply
    );
    const newTokenReceipt = await newTokenTx.wait(1);
    const tokenId =
      newTokenReceipt.events![newTokenReceipt.events!.length - 1].args!.tokenId;

    expect(
      erc1155Contract.mint(tokenId, 11, {
        value: ethers.utils.parseEther("1.1"),
      })
    ).to.rejectedWith("Overflow max supply");
    expect(
      erc1155Contract.mint(tokenId, 8, {
        value: ethers.utils.parseEther("0.7"),
      })
    ).to.rejectedWith("Insufficient amount.");

    const mintTx = await erc1155Contract.mint(tokenId, 8, {
      value: ethers.utils.parseEther("0.8"),
    });
    const tokenOwnership = await erc1155Contract.balanceOf(deployer, tokenId);

    await expect(tokenOwnership).to.be.equal(8);
    const withdrawResult = await erc1155Contract.withdraw(deployer);
    console.log("withdrawResult: ", withdrawResult);
  });
  it("Should be able to mint initial tokens", async () => {
    const { deployer } = await getNamedAccounts();
    expect(
      erc1155Contract.mint(1, 30, { value: ethers.utils.parseEther("3") })
    ).to.rejectedWith("Overflow max supply");
    expect(
      erc1155Contract.mint(2, 10, {
        value: ethers.utils.parseEther("1"),
      })
    ).to.rejectedWith("Insufficient amount.");
    const mintTx = await erc1155Contract.mint(1, 8, {
      value: ethers.utils.parseEther("0.8"),
    });
    const tokenURI = await erc1155Contract.tokenURI(1);
    const expectedURI = ERC1155Options.metadata.baseURI + "1";
    expect(tokenURI).to.be.equal(expectedURI);
  });

  it("Should be able to check token URI", async () => {
    let price = await ethers.utils.parseEther("1");
    let uri = "URI of token";
    let totalSupply = 100;

    const newTokenTx = await erc1155Contract.addNewToken(
      price,
      uri,
      totalSupply
    );

    const newTokenReceipt = await newTokenTx.wait(1);
    const tokenId =
      newTokenReceipt.events![newTokenReceipt.events!.length - 1].args!.tokenId;

    await expect(await erc1155Contract.tokenURI(tokenId)).to.be.equal(uri);
  });

  it("Should be able to transfer nfts", async () => {
    const { deployer, holder } = await getNamedAccounts();
    let price = await ethers.utils.parseEther("0.1");
    let uri = "URI of token";
    let totalSupply = 10;
    const newTokenTx = await erc1155Contract.addNewToken(
      price,
      uri,
      totalSupply
    );
    const newTokenReceipt = await newTokenTx.wait(1);
    const tokenId =
      newTokenReceipt.events![newTokenReceipt.events!.length - 1].args!.tokenId;
    await erc1155Contract.mint(tokenId, 8, {
      value: ethers.utils.parseEther("0.8"),
    });
    await erc1155Contract.safeTransferFrom(
      deployer,
      holder,
      tokenId,
      4,
      toUtf8Bytes("")
    );
    const tokenOwnership = await erc1155Contract.balanceOf(holder, tokenId);
    await expect(tokenOwnership).to.be.equal(4);
  });
});

// // describe("ERC1155 Collection Soulbound tests", async () => {
// //   let proxyManager: ERC1155ProxyManager;
// //   let erc1155Contract: ERC1155Contract;
// //   let proxyAddress: string;
// //   let counter: number = 0;

// //   beforeEach(async () => {
// //     const { deployer } = await getNamedAccounts();
// //     await deployments.fixture(["all"]);

// //     proxyManager = await ethers.getContract(ERC1155_PROXY_MANAGER, deployer);
// //     const ERC1155Implementation = await ethers.getContract(ERC1155_CONTRACT);

// //     ERC1155Options.metadata.defaultAdmin = deployer;
// //     ERC1155Options.masterCopy = ERC1155Implementation.address;
// //     ERC1155Options.metadata.isSoulbound = true;
// //     ERC1155Options.metadata.validity = 0;
// //     const factoryTx = await proxyManager.DeployERC1155(ERC1155Options);
// //     const factoryReceipt = await factoryTx.wait(1);

// //     proxyAddress =
// //       factoryReceipt.events![factoryReceipt.events!.length - 1].args!.newProxy;

// //     erc1155Contract = await ethers.getContractAt(
// //       ERC1155_CONTRACT,
// //       proxyAddress,
// //       deployer
// //     );
// //   });

// //   it("Should be able to add new tokens", async () => {
// //     const { deployer } = await getNamedAccounts();
// //     let price = await ethers.utils.parseEther("1");
// //     let uri = "URI of token";
// //     let totalSupply = 100;

// //     const newTokenTx = await erc1155Contract.addNewToken(
// //       price,
// //       uri,
// //       totalSupply
// //     );

// //     const newTokenReceipt = await newTokenTx.wait(1);
// //     const tokenId =
// //       newTokenReceipt.events![newTokenReceipt.events!.length - 1].args!.tokenId;
// //     await expect(tokenId).to.be.equal(
// //       ERC1155Options.metadata.initialSupply + 1
// //     );

// //     await expect(await erc1155Contract.tokenURI(tokenId)).to.be.equal(uri);
// //   });
// //   it("Should be able to mint new token", async () => {
// //     const { deployer } = await getNamedAccounts();
// //     expect(erc1155Contract.mint(0, 1)).to.rejectedWith("Invalid token id");
// //     let price = await ethers.utils.parseEther("0.1");
// //     let uri = "URI of token";
// //     let totalSupply = 10;
// //     const newTokenTx = await erc1155Contract.addNewToken(
// //       price,
// //       uri,
// //       totalSupply
// //     );
// //     const newTokenReceipt = await newTokenTx.wait(1);
// //     const tokenId =
// //       newTokenReceipt.events![newTokenReceipt.events!.length - 1].args!.tokenId;

// //     expect(
// //       erc1155Contract.mint(tokenId, 11, {
// //         value: ethers.utils.parseEther("1.1"),
// //       })
// //     ).to.rejectedWith("Overflow max supply");
// //     expect(
// //       erc1155Contract.mint(tokenId, 8, {
// //         value: ethers.utils.parseEther("0.7"),
// //       })
// //     ).to.rejectedWith("Insufficient amount.");

// //     const mintTx = await erc1155Contract.mint(tokenId, 8, {
// //       value: ethers.utils.parseEther("0.8"),
// //     });
// //     const tokenOwnership = await erc1155Contract.balanceOf(deployer, tokenId);

// //     await expect(tokenOwnership).to.be.equal(8);
// //   });
// //   it("Should be a Soulbound NFT", async () => {
// //     const { deployer, holder } = await getNamedAccounts();
// //     expect(erc1155Contract.mint(0, 1)).to.rejectedWith("Invalid token id");
// //     let price = await ethers.utils.parseEther("0.1");
// //     let uri = "URI of token";
// //     let totalSupply = 10;
// //     const newTokenTx = await erc1155Contract.addNewToken(
// //       price,
// //       uri,
// //       totalSupply
// //     );
// //     const newTokenReceipt = await newTokenTx.wait(1);
// //     const tokenId =
// //       newTokenReceipt.events![newTokenReceipt.events!.length - 1].args!.tokenId;
// //     await erc1155Contract.mint(tokenId, 8, {
// //       value: ethers.utils.parseEther("0.8"),
// //     });
// //     expect(
// //       erc1155Contract.safeTransferFrom(
// //         deployer,
// //         holder,
// //         tokenId,
// //         4,
// //         toUtf8Bytes("")
// //       )
// //     ).to.rejectedWith("restricted to TRANSFER_ROLE holders.");
// //     const hash = keccak256(toUtf8Bytes("TRANSFER_ROLE"));
// //     const oldstatus = await erc1155Contract.hasRole(hash, deployer);
// //     expect(oldstatus).to.be.equal(false);
// //     await erc1155Contract.grantRole(hash, deployer);
// //     const newstatus = await erc1155Contract.hasRole(hash, deployer);
// //     expect(newstatus).to.be.equal(true);
// //     await erc1155Contract.safeTransferFrom(
// //       deployer,
// //       holder,
// //       tokenId,
// //       4,
// //       toUtf8Bytes("")
// //     );
// //     const tokenBalance = await erc1155Contract.balanceOf(holder, tokenId);
// //     expect(tokenBalance).to.be.equal(4);
// //   });
// // });
// describe("ERC1155 Collection Timebound tests", async () => {
//   let proxyManager: ERC1155ProxyManager;
//   let erc1155Contract: ERC1155Contract;
//   let proxyAddress: string;
//   let counter: number = 0;

//   beforeEach(async () => {
//     const { deployer } = await getNamedAccounts();
//     await deployments.fixture(["all"]);

//     proxyManager = await ethers.getContract(ERC1155_PROXY_MANAGER, deployer);
//     const ERC1155Implementation = await ethers.getContract(ERC1155_CONTRACT);

//     ERC1155Options.metadata.defaultAdmin = deployer;
//     ERC1155Options.masterCopy = ERC1155Implementation.address;
//     ERC1155Options.metadata.isSoulbound = false;
//     /// time bound period
//     ERC1155Options.metadata.validity = 10;
//     const factoryTx = await proxyManager.DeployERC1155(ERC1155Options);
//     const factoryReceipt = await factoryTx.wait(1);

//     proxyAddress =
//       factoryReceipt.events![factoryReceipt.events!.length - 1].args!.newProxy;

//     erc1155Contract = await ethers.getContractAt(
//       ERC1155_CONTRACT,
//       proxyAddress,
//       deployer
//     );
//   });

//   it("Should be able to add new tokens", async () => {
//     const { deployer } = await getNamedAccounts();
//     let price = await ethers.utils.parseEther("1");
//     let uri = "URI of token";
//     let totalSupply = 100;

//     const newTokenTx = await erc1155Contract.addNewToken(
//       price,
//       uri,
//       totalSupply
//     );

//     const newTokenReceipt = await newTokenTx.wait(1);
//     const tokenId =
//       newTokenReceipt.events![newTokenReceipt.events!.length - 1].args!.tokenId;
//     await expect(tokenId).to.be.equal(
//       ERC1155Options.metadata.initialSupply + 1
//     );

//     await expect(await erc1155Contract.tokenURI(tokenId)).to.be.equal(uri);
//   });
//   it("Should be able to mint new token", async () => {
//     const { deployer } = await getNamedAccounts();
//     expect(erc1155Contract.mint(0, 1)).to.rejectedWith("Invalid token id");
//     let price = await ethers.utils.parseEther("0.1");
//     let uri = "URI of token";
//     let totalSupply = 10;
//     const newTokenTx = await erc1155Contract.addNewToken(
//       price,
//       uri,
//       totalSupply
//     );
//     const newTokenReceipt = await newTokenTx.wait(1);
//     const tokenId =
//       newTokenReceipt.events![newTokenReceipt.events!.length - 1].args!.tokenId;

//     expect(
//       erc1155Contract.mint(tokenId, 11, {
//         value: ethers.utils.parseEther("1.1"),
//       })
//     ).to.rejectedWith("Overflow max supply");
//     expect(
//       erc1155Contract.mint(tokenId, 8, {
//         value: ethers.utils.parseEther("0.7"),
//       })
//     ).to.rejectedWith("Insufficient amount.");

//     const mintTx = await erc1155Contract.mint(tokenId, 8, {
//       value: ethers.utils.parseEther("0.8"),
//     });
//     const tokenOwnership = await erc1155Contract.balanceOf(deployer, tokenId);

//     await expect(tokenOwnership).to.be.equal(8);
//   });
//   it("Should be a Timebound NFT", async () => {
//     const { deployer, holder } = await getNamedAccounts();
//     expect(erc1155Contract.mint(0, 1)).to.rejectedWith("Invalid token id");
//     let price = await ethers.utils.parseEther("0.1");
//     let uri = "URI of token";
//     let totalSupply = 10;
//     const newTokenTx = await erc1155Contract.addNewToken(
//       price,
//       uri,
//       totalSupply
//     );
//     const newTokenReceipt = await newTokenTx.wait(1);
//     const tokenId =
//       newTokenReceipt.events![newTokenReceipt.events!.length - 1].args!.tokenId;
//     await erc1155Contract.mint(tokenId, 8, {
//       value: ethers.utils.parseEther("0.8"),
//     });
//     await erc1155Contract.safeTransferFrom(
//       deployer,
//       holder,
//       tokenId,
//       4,
//       toUtf8Bytes("")
//     );
//     const tokenBalance = await erc1155Contract.balanceOf(holder, tokenId);
//     expect(tokenBalance).to.be.equal(4);
//     await new Promise((resolve) => setTimeout(resolve, 20000));
//     await expect(
//       erc1155Contract.safeTransferFrom(
//         deployer,
//         holder,
//         tokenId,
//         2,
//         toUtf8Bytes("")
//       )
//     ).to.rejectedWith("Time bounding period is expired.");
//   });
// });
