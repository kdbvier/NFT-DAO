//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interface/ITBT.sol";

abstract contract TimeboundToken is ITBT {
    // Default or set value for expirary time
    uint256 private validFor;

    // Mapping to track all the token id with expiry timestamp
    mapping(uint256 => uint256) private tokenValidity;

    function SetValidity(uint256 _validFor) internal {
        // require(canSetValidity(), "TBT: Only owner can set expirary parameter.");
        validFor = _validFor;
        emit ExpiraryTimeUpdated(validFor);
    }

    function UpdateTokenValidity(uint256 _tokenId) internal {
        uint256 curTime = block.timestamp;
        tokenValidity[_tokenId] = curTime + validFor;

        emit ValidityUpdated(_tokenId, curTime);
    }

    function hasExpired(uint256 _tokenId) public view override returns (bool) {
        // get current blocktimestamp

        /*
            V = E - T
            Validity = expiry - Current Timestamp (elapsed time)
        */

        uint256 _validTill = tokenValidity[_tokenId];
        bool reValidity = block.timestamp > _validTill;
        return reValidity;
    }

    /// @dev returns true if value can be set
    function canSetValidity() internal view virtual returns (bool);
}
