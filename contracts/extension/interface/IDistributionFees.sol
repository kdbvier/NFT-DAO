// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IDistributionFees {
    /// @dev Returns the Distribution fee bps and recipient.
    function getDistributionFeeInfo() external view returns (address, uint16);

    /// @dev Lets a module admin update the fees on primary sales.
    function setDistributionFeeInfo(address _DistributionFeeRecipient, uint256 _DistributionFeeBps) external;

    /// @dev Emitted when fee on primary sales is updated.
    event DistributionFeeInfoUpdated(address indexed DistributionFeeRecipient, uint256 DistributionFeeBps);
}