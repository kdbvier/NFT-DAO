// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library FeeCalculator {
    using SafeMath for uint256;
    function calculateFee(uint256 value, uint256 fee) public pure returns(uint256) {
        return value.div(1e3).mul(fee).div(10);
    }
}