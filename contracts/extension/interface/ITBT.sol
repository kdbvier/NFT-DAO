//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interface for Time Bound Tokens
// This inteface defines validity of the tokens based on specified timelimit
interface ITBT {

    // Sets validity of the token - NOTE: Only called during token mint set validity of the token
    /*
        uint256: expiray timestamp for which validity is set
    */
    // function SetValidity(uint256) external;

    // Checks the validity of the token based on expiry date
    /*
        @params uint256: TokenId to check is this token valid or expired
        Returns: true if token is valid else false if expired
    */
    function hasExpired(uint256 tokenId) external returns (bool);
    
    // event: Emitted with set validity
    /*
        uint256: tokenID for which validity is set
        uint256: expiry timestamp for the current token
    */
    event ValidityUpdated(uint256 tokenId, uint256 timeStamp);
    event ExpiraryTimeUpdated(uint256);
}