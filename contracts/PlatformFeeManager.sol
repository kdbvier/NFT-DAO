// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./interfaces/IDecirTreasury.sol";
import "./extension/interface/IPrimarySaleFees.sol";
import "./extension/interface/IPlatformFees.sol";
import "./extension/interface/IDistributionFees.sol";

/// @dev Manages all the platform related fees.
/// @dev Helps setup fee structure and recipient of fees
contract PlatformFeeManager is 
    Initializable,
    AccessControlUpgradeable,
    IPrimarySaleFees,
    IPlatformFees,
    IDistributionFees
{
    // Define roles here
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    // TODO Make all this private and editable only by admin
    uint16 private PRIMARY_SALE_COMMISSION; // 10%
    uint16 private DISTRIBUTION_FEES;  // 3.75%
    uint16 private PLATFORM_FEES;
    address private feeRecipient;

    event OperatorUpdated(address newOperator);

    function initialize(address _recipient) initializer public {

        PRIMARY_SALE_COMMISSION = 1000;
        DISTRIBUTION_FEES = 375;
        PLATFORM_FEES = 0;

        // ! Make current user default admin
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        feeRecipient = _recipient;

    }

    // ? Update operator - only default admin can update
    function setOperator(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(OPERATOR_ROLE, account);
        emit OperatorUpdated(account);
    }

    //* Setup primary sales fees 
    function primarySaleFeeRecipient() public override view returns (address, uint256) {
        return (feeRecipient, PRIMARY_SALE_COMMISSION);
    }

    function setPrimarySaleFeeRecipient(address _salesFeeRecipient , uint256 _salesFeeBps) public override onlyRole(OPERATOR_ROLE) {

        // ! CANNOT override feeRecipient
        feeRecipient = _salesFeeRecipient;
        PRIMARY_SALE_COMMISSION = uint16(_salesFeeBps);

        emit PrimarySaleFeeRecipientUpdated(feeRecipient, PRIMARY_SALE_COMMISSION);
    }

    // * Setup platform fees
    function getPlatformFeeInfo() public override view returns (address, uint16) {
        return (feeRecipient, PLATFORM_FEES);
    }

    function setPlatformFeeInfo(address _recipient, uint256 _bps) public override onlyRole(OPERATOR_ROLE) {
        // ! CANNOT override feeRecipient
        feeRecipient = _recipient;
        PLATFORM_FEES = uint16(_bps);

        emit PlatformFeeInfoUpdated(feeRecipient, PLATFORM_FEES);
    }

    // * Setup configuration for distribution fees
    function getDistributionFeeInfo() public override view returns (address, uint16) {
        return (feeRecipient, DISTRIBUTION_FEES);
    }

    function setDistributionFeeInfo(
        address _DistributionFeeRecipient, 
        uint256 _DistributionFeeBps
    ) public override onlyRole(OPERATOR_ROLE) {
        // ! CANNOT override feeRecipient
        feeRecipient = _DistributionFeeRecipient;
        DISTRIBUTION_FEES = uint16(_DistributionFeeBps);

        emit DistributionFeeInfoUpdated(feeRecipient, DISTRIBUTION_FEES);
    }
}
