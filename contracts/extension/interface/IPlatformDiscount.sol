// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;


interface IPlatformDiscount  {
    function isDiscountApplied(address, uint16) external returns (bool);
    function isPartner(address) external view returns (bool);
}