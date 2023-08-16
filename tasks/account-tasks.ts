import { task } from "hardhat/config";

task("balance", "Print account balance")
  .addParam("address", "account's address")
  .setAction(async (address: string) => {
    // console.log(
    //   `\t Current network ${(await ethers.provider.getNetwork()).name}`
    // );
    console.log(`\t Balance is Calculated here`);
  });

export {};
