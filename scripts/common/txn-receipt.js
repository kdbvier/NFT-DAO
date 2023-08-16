const Web3 = require("web3");

(async () => {
  try {
    const providerUrl =
      "https://eth-goerli.g.alchemy.com/v2/tNTIJvU5ecHA7ZLCx-kCyyBFSbdfQTmN";
    const providerUrl60 =
      "https://eth-mainnet.g.alchemy.com/v2/Ff7R6pWVFh9U6qwo4lkH0Mb5MchQLc05";
    const web3 = new Web3(providerUrl);

    let functions = [
      "OwnerUpdated(address,address)",
      "PrimarySaleRecipientUpdated(address)",
      "DefaultRoyalty(address,uint128)",
      "RoyaltyFoToken(uint256,address,uint128)",
      "TokenMinted(address,uint256)",
      "ProxyCreated(address)",
      "TransferSingle(address,address,address,uint256,uint256)",
      "TokenCreated(uint256)",
    ];

    functions.forEach((element) => {
      console.log(`\t Topic hash of ${element} is ${web3.utils.sha3(element)}`);
    });

    // const proxyCreated = web3.utils.sha3("TokenMinted(uint256,string)");
    // const treasuryUpdated = web3.utils.sha3("TreasuryUpdated(address)");
    // console.log(`Proxy created : ${proxyCreated}`);
    // console.log(`Treasury updated : ${treasuryUpdated}`);
  } catch (e) {
    console.log(e.message);
  }
})();
