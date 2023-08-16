// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IPrimarySaleFees {
    /// @dev The adress that receives all primary sales value.
    function primarySaleFeeRecipient() external view returns (address, uint256);

    /// @dev Lets a module admin set the default recipient of all primary sales.
    function setPrimarySaleFeeRecipient(address _salesFeeRecipient , uint256 _salesFeeBps) external;

    /// @dev Emitted when a new sale recipient is set.
    event PrimarySaleFeeRecipientUpdated(address indexed salesFeeRecipient, uint256 _salesFeeBps);
}
