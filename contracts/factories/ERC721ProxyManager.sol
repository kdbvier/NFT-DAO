//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/Config.sol";
import "../proxy/GenericProxyV2.sol";
import "../v2/ERC721Contract.sol";

contract ERC721ProxyManager {
    event ProxyCreated(address newProxy);

    constructor() {}

    function DeployERC721(
        Config.ERC721DeployRequest memory params
    ) public {
        bytes memory data;
        data = abi.encodeWithSelector(
            ERC721Contract(params.masterCopy).initialize.selector,
            params.metadata
        );

        GenericProxyV2 newProxy = new GenericProxyV2(
            params.masterCopy,
            data
        );

        emit ProxyCreated(address(newProxy));
    }
}