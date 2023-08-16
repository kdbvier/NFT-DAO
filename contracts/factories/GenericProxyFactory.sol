//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/MinimalForwarderUpgradeable.sol";
import "@openzeppelin/contracts/metatx/MinimalForwarder.sol"; // for conversion
import "../proxy/GenericProxy.sol";
import "../ERC721Collection.sol";
import "../MembershipCollection.sol";
import "../CreatorDAO.sol";
import "../RoyaltySplitter.sol";
import "../lib/Config.sol";

contract GenericProxyFactory is ERC2771ContextUpgradeable {
    event ProxyCreated(address newProxy);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(MinimalForwarderUpgradeable _minimalForwarder)
        ERC2771ContextUpgradeable(address(_minimalForwarder))
    {}

    function createDAOProxy(Config.DaoProxy memory _config) public {
        address master;
        address minimalForwarder = address(_config.forwarder);
        bytes memory data;

        if (_config.isDAO) {
            Config.DAOConfig memory _daoConfig = _config.dao;
            master = address(_daoConfig.masterCopy);
            data = abi.encodeWithSelector(
                CreatorDAO(master).initialize.selector,
                _daoConfig.safeFactory,
                _daoConfig.singleton,
                _daoConfig.setupData,
                _daoConfig.nonce,
                _daoConfig.hasTreasury,
                _daoConfig.safeProxy,
                _daoConfig.creator
            );
        }

        GenericProxy newProxy = new GenericProxy(
            master,
            data,
            minimalForwarder
        );

        emit ProxyCreated(address(newProxy));
    }

    function _createDefaultSplitterProxy(
        address _masterCopy,
        address _minimalForwarder
    ) internal returns (address) {
        // Deploy default royalty splitter
        address[] memory receivers = new address[](1);
        receivers[0] = _msgSender();

        uint256[] memory shares = new uint256[](1);
        shares[0] = 100; // ! make default share as 100 for the creator.

        // Use same forwarder with collection
        address forwarder = address(_minimalForwarder);
        // address decirContract = address(_decirContract);
        // address discountContract = address(_discountContract);
        // Set caller as creator
        address creator = _msgSender();
        // use mastercopy of old collection
        address masterCopy = _masterCopy;

        Config.PaymentSplitter memory psConfig = Config.PaymentSplitter({
            receivers: receivers,
            shares: shares,
            masterCopy: masterCopy,
            creator: creator,
            forwarder: forwarder
        });

        address royaltyProxy = createRoyaltyProxy(psConfig);
        return royaltyProxy;
    }

    function createCollectionProxy(Config.CollectionProxy memory _config)
        public
    {
        // Config.Runtime memory _runConfig = _config.collection.runConfig;

        // // If royalty splitter is not set, deploy default one
        // if (_runConfig.royaltyAddress == address(0)) {
        //     address royaltyProxy = _createDefaultSplitterProxy(
        //         _config.royaltyMaster,
        //         _config.decirTreasury,
        //         _config.discount,
        //         _config.forwarder
        //     );
        //     // Update conf param with deployed royalty proxy
        //     _config.collection.runConfig.royaltyAddress = royaltyProxy;
        // }

        // Create Collection Proxy
        _createCollectionProxy(_config);
    }

    function _createCollectionProxy(Config.CollectionProxy memory _config)
        internal
    {
        address master;
        address minimalForwarder = address(_config.forwarder);
        bytes memory data;

        Config.Deployment memory _deployConfig = _config
            .collection
            .deployConfig;
        Config.Runtime memory _runConfig = _config.collection.runConfig;

        master = address(_deployConfig.masterCopy);
        data = abi.encodeWithSelector(
            ERC721Collection(master).initialize.selector,
            _deployConfig.name,
            _deployConfig.symbol,
            _deployConfig.owner,
            _runConfig.baseURI,
            _runConfig.royaltiesBps,
            _runConfig.royaltyAddress,
            _runConfig.maxSupply,
            _runConfig.floorPrice
            // _config.decirTreasury,
            // _config.discount
        );

        GenericProxy newProxy = new GenericProxy(
            master,
            data,
            minimalForwarder
        );

        emit ProxyCreated(address(newProxy));
    }

    function createMembershipProxy(Config.CollectionProxy memory _config)
        public
    {
        // Config.Runtime memory _runConfig = _config.collection.runConfig;

        // // If royalty splitter is not set, deploy default one
        // if (_runConfig.royaltyAddress == address(0)) {
        //     address royaltyProxy = _createDefaultSplitterProxy(
        //         _config.royaltyMaster,
        //         _config.decirTreasury,
        //         _config.discount,
        //         _config.forwarder
        //     );
        //     // Update conf param with deployed royalty proxy
        //     _config.collection.runConfig.royaltyAddress = royaltyProxy;
        // }

        // Create Collection Proxy
        _createMembershipProxy(
            _config,
            // _config.collection.runConfig.baseURI,
            // _config.collection.runConfig.royaltiesBps,
            // _config.collection.runConfig.royaltyAddress,
            _config.collection.deployConfig.masterCopy
        );
    }

    function _createMembershipProxy(
        Config.CollectionProxy memory _config,
        address masterCopy
    ) internal {
        address master;
        address minimalForwarder = address(_config.forwarder);
        bytes memory data;

        // if (_config.isCollection) {
        //     Config.Deployment memory _deployConfig = _config
        //         .collection
        //         .deployConfig;
        //     Config.Runtime memory _runConfig = _config.collection.runConfig;

        master = address(masterCopy);
        data = abi.encodeWithSelector(
            MembershipCollection(master).initialize.selector,
            _config
        );
        // }

        GenericProxy newProxy = new GenericProxy(
            master,
            data,
            minimalForwarder
        );

        emit ProxyCreated(address(newProxy));
    }

    function createRoyaltyProxy(Config.PaymentSplitter memory _config)
        public
        returns (address)
    {
        GenericProxy newProxy = new GenericProxy(
            address(_config.masterCopy),
            abi.encodeWithSelector(
                RoyaltySplitter(payable(address(uint160(_config.masterCopy))))
                    .initialize
                    .selector,
                _config.shares,
                _config.receivers,
                _config.creator
            ),
            _config.forwarder
        );

        emit ProxyCreated(address(newProxy));

        return address(newProxy);
    }
}
