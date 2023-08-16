//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/Config.sol";
import "../proxy/GenericProxyV2.sol";
import "../v2/ERC1155Contract.sol";

contract ERC1155ProxyManager {
    event ProxyCreated(address newProxy);

    constructor() {}

    function DeployERC1155(
        Config.ERC1155DeployRequest memory params
    ) public {
        bytes memory data;
        data = abi.encodeWithSelector(
            ERC1155Contract(params.masterCopy).initialize.selector,
            params.metadata
        );

        GenericProxyV2 newProxy = new GenericProxyV2(
            params.masterCopy,
            data
        );

        emit ProxyCreated(address(newProxy));
    }
}