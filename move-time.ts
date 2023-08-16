import { network } from "hardhat";

export async function moveTime(amount: number) {
  console.log(`\t Moving time by ${amount} seconds`);
  await network.provider.send("evm_increaseTime", [amount]);
  console.log(`\t Moved time forward by ${amount} seconds`);
}
