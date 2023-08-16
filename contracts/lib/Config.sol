// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Config {
    struct Deployment {
        string name;
        string symbol;
        address owner;
        address masterCopy;
    }

    struct Runtime {
        string baseURI;
        uint256 royaltiesBps;
        address royaltyAddress;
        uint256 maxSupply;
        uint256 floorPrice;
        uint256 validity;
    }

    struct PaymentSplitter {
        address[] receivers;
        uint256[] shares;
        address masterCopy;
        address creator;
        address forwarder;
    }

    struct DAOConfig {
        address masterCopy;
        address safeFactory;
        address singleton;
        bytes setupData;
        uint256 nonce;
        bool hasTreasury;
        address safeProxy;
        address creator;
    }

    struct TierConfig {
        string tierId;
        uint256 floorPrice;
        uint256 totalSupply;
    }

    struct CollectionConfiguration {
        Deployment deployConfig;
        Runtime runConfig;
    }

    struct DaoProxy {
        bool isDAO;
        DAOConfig dao;
        address forwarder;
    }

    struct CollectionProxy {
        // bool isCollection;
        bool isLocked;
        CollectionConfiguration collection;
        // address decirTreasury;
        // address discount;
        address forwarder;
    }

    struct RoyaltyProxy {
        bool isRoyalty;
        PaymentSplitter royalty;
        address forwarder;
    }

    struct ERC721Params {
        address defaultAdmin;
        string name;
        string symbol;
        string contractURI;
        string baseURI;
        address royaltyRecipient;
        uint128 royaltyBps;
        address primarySaleRecipient;
        uint256 floorPrice;
        uint256 maxSupply;
        uint256 initialSupply;
        address platformFeeManager;
        uint256 validity;
        bool isSoulbound;
    }

    struct ERC1155Params {
        address defaultAdmin;
        string name;
        string symbol;
        string contractURI;
        string baseURI;
        address royaltyRecipient;
        uint128 royaltyBps;
        address primarySaleRecipient;
        address platformFeeManager;
        uint256 initialSupply;
        uint256[] initialPrices;
        uint256[] initialMaxSupplies;
        uint256 validity;
        bool isSoulbound;
    }

    struct ERC721DeployRequest {
        ERC721Params metadata;
        address masterCopy;
    }

    struct ERC1155DeployRequest {
        ERC1155Params metadata;
        address masterCopy;
    }
}
