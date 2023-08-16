// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IDecirTreasury {
    function primarySaleFeeRecipient() external view returns(address, uint256);
}
