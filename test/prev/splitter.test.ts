import { ethers, getNamedAccounts, deployments } from "hardhat";
import { expect } from "chai";
import { GenericProxyFactory, RoyaltySplitter } from "../../typechain-types";
import {
  GENERIC_PROXY_FACTORY,
  MINIMAL_FORWARDER,
  NUMERICAL_CONSTANT,
  ROYALTY_SPLITTER,
} from "../../helper-hardhat-config";

describe("Royalty splitter test cases", async () => {
  // 0. Deploy splitter
  // 1. Check the splits
  // 2. Check withdrawal for each selected users

  let factory: GenericProxyFactory;
  let splitter: RoyaltySplitter;
  let royaltyConfig: any;
  let proxyAddress: string;

  beforeEach(async () => {
    const { deployer } = await getNamedAccounts();
    await deployments.fixture(["all"]);
    factory = await ethers.getContract(GENERIC_PROXY_FACTORY);

    const shares = [100];
    royaltyConfig = {
      receivers: [deployer],
      shares: shares.map((x) => ethers.utils.parseUnits(x.toString())),
      masterCopy: (await ethers.getContract(ROYALTY_SPLITTER)).address,
      forwarder: (await ethers.getContract(MINIMAL_FORWARDER)).address,
      creator: deployer,
    };

    const factoryTx = await factory.createRoyaltyProxy(royaltyConfig);
    const factoryReceipt = await factoryTx.wait(1);

    proxyAddress =
      factoryReceipt.events![factoryReceipt.events!.length - 1].args!.newProxy;

    // Deploy new royalty splitter
    splitter = await ethers.getContractAt(
      ROYALTY_SPLITTER,
      proxyAddress,
      deployer
    );
  });

  it("Should match owner of royalty", async () => {
    const { deployer } = await getNamedAccounts();
    const owner = await splitter.owner();
    await expect(deployer).to.be.equal(owner);
  });

  it("Check total number of payees", async () => {
    const totalPayees = await splitter.totalPayees();
    await expect(royaltyConfig.receivers.length).to.be.equal(totalPayees);
  });

  it("Should be able to update payees and shares", async () => {
    const { deployer, holder } = await getNamedAccounts();
    royaltyConfig.receivers = [deployer, holder];
    const updatedShares = [50, 50];
    royaltyConfig.shares = updatedShares.map((x) =>
      ethers.utils.parseUnits(x.toString())
    );

    const updateSharesTx = await splitter.updateShares(
      royaltyConfig.receivers,
      royaltyConfig.shares
    );

    await updateSharesTx.wait(1);
    const totalPayees = await splitter.totalPayees();

    await expect(royaltyConfig.receivers.length).to.be.equal(totalPayees);
  });

  it("Should always contain 100% shares", async () => {
    const updatedShares = [50, 50];
    let aggregatedShares = 0;
    const totalShares =
      Number(await splitter.totalShares()) / NUMERICAL_CONSTANT;
    aggregatedShares = updatedShares.reduce(
      (aggregatedShares, x) => aggregatedShares + x,
      0
    );

    await expect(aggregatedShares).to.be.equal(totalShares);
  });
});
