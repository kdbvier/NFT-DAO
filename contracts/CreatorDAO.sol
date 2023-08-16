// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/MinimalForwarderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";

// initializable and ownable
contract CreatorDAO is Initializable, OwnableUpgradeable, ERC2771ContextUpgradeable  {
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;

    string public name;
    address private treasuryAddress;

    GnosisSafeProxyFactory safeFactory;
    event TreasuryUpdated(address treasury);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        MinimalForwarderUpgradeable _minimalFowarder
    ) ERC2771ContextUpgradeable(
        address(_minimalFowarder)
    ) { }

    function initialize( 
        address _safeFactory, 
        address _singleton,
        bytes memory _setupData, 
        uint256 _nonce,
        bool _hasTreasury,
        address _safeProxy,
        address _creator
    ) external initializer {

        __Ownable_init();
        _transferOwnership(_creator);

        // name = _name;

        if(_hasTreasury) {
            treasuryAddress = _safeProxy;
        } else {
            
           address gnosisProxy = _provisionTreasury(_safeFactory, _singleton, _setupData, _nonce);
            treasuryAddress = gnosisProxy;
        }
        
    }

    function _provisionTreasury(
        address _safeFactory, 
        address _singleton, 
        bytes memory _setupData, 
        uint256 _nonce
    ) internal returns (address) {
        safeFactory = GnosisSafeProxyFactory(_safeFactory);
        GnosisSafeProxy gnosisProxy =  safeFactory.createProxyWithNonce(_singleton, _setupData, _nonce);
        return address(gnosisProxy);
    }

    
    function setTreasury(address _treasury) public onlyOwner {
        treasuryAddress = _treasury;
        emit TreasuryUpdated(treasuryAddress);
    }


    // TODO Sales revenue from DAO contract 


    function getTreasury() public view returns (address) {
        return treasuryAddress;
    }

    function balance() public view returns (uint256) {
        return address(treasuryAddress).balance;
    }

    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns(address) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns(bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    } 
}
