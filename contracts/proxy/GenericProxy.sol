// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";

contract GenericProxy is ERC1967Proxy, ERC2771Context {
    uint32 private version;
    
    constructor(
        address _logic, 
        bytes memory _data,
        address _minimalForwarder
    ) ERC1967Proxy(_logic, _data) ERC2771Context(address(_minimalForwarder)) {}

    function versionProxy() public view returns(uint32) {
        return version;
    }

    function upgradeTo(address implementation) public {
        super._upgradeTo(implementation);
    }
}
