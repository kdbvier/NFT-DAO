import {
  GenericProxyFactory,
  MembershipCollection,
} from "../../typechain-types";
import { deployments, ethers, getNamedAccounts, network } from "hardhat";
import {
  DEFAULT_TREASURY,
  GENERIC_PROXY_FACTORY,
  MEMBERSHIP_NFT_CONTRACT,
  MINIMAL_FORWARDER,
  TIERS,
  TOKEN_VALIDITY,
  developmentChains,
} from "../../helper-hardhat-config";
import { expect } from "chai";
import { moveBlock } from "../../move-blocks";
import { moveTime } from "../../move-time";

/*
  1. initialize new contract
  2. Setup tiers for membership contract
  3. Make it an SBT
  4. Expiry date for the token 
  5. move time and check validity
*/

describe("Membership NFT Flow", async () => {
  let factory: GenericProxyFactory;
  let membership: MembershipCollection;
  let proxyAddress: string;
  let counter: number = 0;
  //   let membershipConfig: Config.CollectionProxyStruct;
  let membershipConfig: any;

  beforeEach(async () => {
    const { deployer } = await getNamedAccounts();
    await deployments.fixture(["all"]);
    factory = await ethers.getContract(GENERIC_PROXY_FACTORY);

    membershipConfig = {
      isLocked: false,
      forwarder: (await ethers.getContract(MINIMAL_FORWARDER)).address,
      collection: {
        deployConfig: {
          name: "NAME",
          symbol: "NE",
          owner: deployer,
          masterCopy: (await ethers.getContract(MEMBERSHIP_NFT_CONTRACT))
            .address,
        },
        runConfig: {
          baseURI: "baseURIhere",
          floorPrice: await ethers.utils.parseEther("1"),
          maxSupply: 0,
          royaltiesBps: 100,
          royaltyAddress: DEFAULT_TREASURY,
          validity: TOKEN_VALIDITY,
        },
      },
    };

    const factoryTx = await factory.createMembershipProxy(membershipConfig);
    const factoryReceipt = await factoryTx.wait(1);

    proxyAddress =
      factoryReceipt.events![factoryReceipt.events!.length - 1].args!.newProxy;

    membership = await ethers.getContractAt(
      MEMBERSHIP_NFT_CONTRACT,
      proxyAddress,
      deployer
    );

    const setTiersTx = await membership.setTiers(TIERS);
    const setTiersReceipt = await setTiersTx.wait(1);
    await expect(
      setTiersReceipt.events![setTiersReceipt.events!.length - 1].args!.status
    ).to.be.equal(true);
  });

  it("Can initialize new contract here", async () => {
    const { deployer } = await getNamedAccounts();
    const owner = await membership.owner();
    await expect(owner).to.be.equal(deployer);
  });

  it("Should be able to mint new token with selected tier", async () => {
    const { deployer } = await getNamedAccounts();
    const tokenURI: string = "tokenURI";
    const mintTokenTx = await membership.mintToCaller(
      deployer,
      tokenURI,
      TIERS[0].tierId,
      { value: TIERS[0].floorPrice }
    );
    counter += 1;

    const mintTokenReceipt = await mintTokenTx.wait(1);
    const tokenId =
      mintTokenReceipt.events![mintTokenReceipt.events!.length - 1].args!
        .tokenId;
    const uri =
      mintTokenReceipt.events![mintTokenReceipt.events!.length - 1].args!
        .tokenURI;

    await expect(Number(tokenId)).to.be.equal(counter);
    await expect(uri).to.be.equal(tokenURI);
    await expect(await membership.ownerOf(counter)).to.be.equal(deployer);
  });

  it("Should be an Soul-bound NFT", async () => {
    const { deployer, holder } = await getNamedAccounts();
    const tokenURI: string = "tokenURI";
    const mintTokenTx = await membership.mintToCaller(
      deployer,
      tokenURI,
      TIERS[0].tierId,
      { value: TIERS[0].floorPrice }
    );

    const mintTokenReceipt = await mintTokenTx.wait(1);
    const tokenId =
      mintTokenReceipt.events![mintTokenReceipt.events!.length - 1].args!
        .tokenId;

    if (membershipConfig.isLocked)
      await expect(membership.transferFrom(deployer, holder, tokenId)).to.be
        .reverted;
    else {
      // check before transfer
      const tokenOwner = await membership.ownerOf(tokenId);
      await expect(tokenOwner).to.be.equal(deployer);
      const transferFromTx = await membership.transferFrom(
        deployer,
        holder,
        tokenId
      );
      const transferFromReceipt = await transferFromTx.wait(1);
      const transferredTokenId =
        transferFromReceipt.events![transferFromReceipt.events!.length - 1]
          .args!.tokenId;
      await expect(transferredTokenId).to.be.equal(tokenId);
    }
  });

  it("Should be an Time-bound NFT", async () => {
    const { deployer, holder } = await getNamedAccounts();
    const tokenURI: string = "tokenURI";
    const mintTokenTx = await membership.mintToCaller(
      deployer,
      tokenURI,
      TIERS[0].tierId,
      { value: TIERS[0].floorPrice }
    );

    const mintTokenReceipt = await mintTokenTx.wait(1);
    const tokenId =
      mintTokenReceipt.events![mintTokenReceipt.events!.length - 1].args!
        .tokenId;
    const validity =
      mintTokenReceipt.events![mintTokenReceipt.events!.length - 2].args!
        .timeStamp;

    let isValid = await membership.hasExpired(tokenId);
    await expect(isValid).to.be.equal(true);
    if (developmentChains.includes(network.name)) {
      await moveTime(TOKEN_VALIDITY + 1);
      await moveBlock(1);
    }
    isValid = await membership.hasExpired(tokenId);
    await expect(isValid).to.be.equal(false);
  });
});
