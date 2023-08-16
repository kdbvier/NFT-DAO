// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./extension/interface/IDiscount.sol";
import "./MembershipNFT.sol";

// TODO: This is not required here
contract Discounts is IDiscount {

    address public immutable membershipPass;

    constructor(address _pass) {
        membershipPass = _pass;
    }

    function isPartner(address _creator) public override view returns (bool) {
        uint256 passCount_ = DecirMembership(membershipPass).balanceOf(_creator, 1);
        return (passCount_ > 0);
    }

    function isDiscountApplied(
        address _creator, 
        uint16 _discountType
    ) public override view returns (bool) {
        return isPartner(_creator) || 
        (DecirMembership(membershipPass).balanceOf(_creator, _discountType) > 0);
    }
}