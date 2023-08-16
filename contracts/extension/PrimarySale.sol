// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interface/IPrimarySale.sol";

abstract contract PrimarySale is IPrimarySale {
    address private recipient;
    uint256 private sellPrice;

    function primarySaleRecipient() public view returns (address) {
        return recipient;
    }

    function setPrimarySaleRecipient(address _saleRecipient, uint256 _sellPrice) external {
        if(!_canSetPrimarySaleRecipient()) {
            revert("Not authorized");
        }
        _setupPrimarySaleRecipient(_saleRecipient, _sellPrice);
    }

    function _setupPrimarySaleRecipient(address _saleRecipient, uint256 _sellPrice) internal {
        recipient = _saleRecipient;
        emit PrimarySaleRecipientUpdated(_saleRecipient);
    }

    /// @dev Returns whether primary sale recipient can be set in the given execution context.
    function _canSetPrimarySaleRecipient() internal view virtual returns (bool);
} 