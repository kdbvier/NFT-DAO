//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interface for 1155 contract
import "../interfaces/token/ITokenERC1155.sol";

import "../interfaces/IDecirContract.sol";
import "../extension/interface/IPrimarySale.sol";
import "../extension/interface/IPlatformFees.sol";
import "../extension/interface/IRoyalty.sol";
import "../extension/interface/IOwnable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

// Signature
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// Math Utils
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Opensea enforcement
import "../extension/DefaultOperatorFiltererUpgradeable.sol";

// Configuration
import "../lib/Config.sol";

// Timebond
import "../extension/TimeboundToken.sol";
import "hardhat/console.sol";

contract ERC1155Contract is
    Initializable,
    IDecirContract,
    IOwnable,
    IRoyalty,
    IPrimarySale,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    OwnableUpgradeable,
    AccessControlEnumerableUpgradeable,
    DefaultOperatorFiltererUpgradeable,
    ERC1155Upgradeable,
    ITokenERC1155,
    TimeboundToken
{
    using StringsUpgradeable for uint256;
    using SafeMath for uint256;

    bytes32 private constant MODULE_TYPE = bytes32("ERC1155Token");
    uint256 private constant VERSION = 1;
    uint256 private constant MAX_BPS = 10_000;
    bytes32 private constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");
    uint256 public constant MAX_INT = 2 ** 256 - 1;

    /// @dev Contract-level metadata

    // Token name
    string public name;
    // Token symbol
    string public symbol;

    string public baseURI;
    string private _contractURI;
    address private _owner;
    uint256 public nextTokenIdToMint;
    address public primarySaleRecipient;
    address public platformFeeRecipient;
    address private royaltyRecipient;
    address private platformFeeManager;
    uint128 private royaltyBps;
    uint128 private platformFeeBps;
    uint256 initialSupply;
    uint256[] initialPrices;
    uint256[] initialMaxSupplies;

    /// @dev Soulbound standard
    bool public isSoulbound;

    /// @dev Timebound standard
    bool public isTimebound;

    mapping(uint256 => ERC1155Token) public nfts;
    mapping(uint256 => string) internal _tokenUris;
    mapping(uint256 => RoyaltyInfo) private royaltyInfoForToken;
    mapping(uint256 => uint256) public totalSupply;

    event TokenCreated(uint256 tokenId);

    function initialize(
        Config.ERC1155Params calldata params
    ) external initializer {
        __ReentrancyGuard_init();
        __EIP712_init("ERC1155Token", "1");
        __Ownable_init();
        __ERC1155_init("");

        _transferOwnership(params.defaultAdmin);

        __DefaultOperatorFilterer_init();
        _setOperatorRestriction(true);

        name = params.name;
        symbol = params.symbol;

        royaltyRecipient = params.royaltyRecipient;
        royaltyBps = params.royaltyBps;

        primarySaleRecipient = params.primarySaleRecipient;

        baseURI = params.baseURI;

        _setupRole(DEFAULT_ADMIN_ROLE, params.defaultAdmin);
        _contractURI = params.contractURI;
        _owner = params.defaultAdmin;

        nextTokenIdToMint = params.initialSupply + 1; /// @dev setting initial token id that will be minted.
        initialSupply = params.initialSupply;
        initialPrices = params.initialPrices;
        initialMaxSupplies = params.initialMaxSupplies;
        isSoulbound = params.isSoulbound;
        // Setup platform fee manager
        platformFeeManager = params.platformFeeManager;
        if (!isSoulbound && params.validity > 0) {
            isTimebound = true;
            SetValidity(params.validity);
        }
    }

    // Interface IDecirContract
    function contractType() external pure override returns (bytes32) {
        return MODULE_TYPE;
    }

    function contractVersion() external pure override returns (uint8) {
        return uint8(VERSION);
    }

    function setContractURI(
        string calldata _uri
    ) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        _contractURI = _uri;
    }

    function contractURI() external view override returns (string memory) {
        return _contractURI;
    }

    // Interface IOwnable
    function owner()
        public
        view
        override(OwnableUpgradeable, IOwnable)
        returns (address)
    {
        return hasRole(DEFAULT_ADMIN_ROLE, _owner) ? _owner : address(0);
    }

    function setOwner(
        address _newOwner
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _newOwner),
            "new owner is not module admin"
        );

        address _preOwner = _owner;
        _owner = _newOwner;

        emit OwnerUpdated(_preOwner, _newOwner);
    }

    // primary sales recipient
    function setPrimarySaleRecipient(
        address _saleRecipient
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        primarySaleRecipient = _saleRecipient;
        emit PrimarySaleRecipientUpdated(_saleRecipient);
    }

    // * Royalty for tokens

    function setDefaultRoyaltyInfo(
        address _royaltyRecipient,
        uint256 _royaltyBps
    ) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_royaltyBps <= MAX_BPS, "exceed royalty bps");

        royaltyRecipient = _royaltyRecipient;
        royaltyBps = uint128(_royaltyBps);

        emit DefaultRoyalty(_royaltyRecipient, _royaltyBps);
    }

    function setRoyaltyInfoForToken(
        uint256 _tokenId,
        address _recipient,
        uint256 _bps
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_bps <= MAX_BPS, "exceed royalty bps");

        royaltyInfoForToken[_tokenId] = RoyaltyInfo({
            recipient: _recipient,
            bps: _bps
        });
        emit RoyaltyForToken(_tokenId, _recipient, _bps);
    }

    /// @dev Returns the platform fee bps and recipient.
    function getDefaultRoyaltyInfo()
        external
        view
        override
        returns (address, uint16)
    {
        return (royaltyRecipient, uint16(royaltyBps));
    }

    /// @dev Returns the royalty recipient for a particular token Id.
    function getRoyaltyInfoForToken(
        uint256 _tokenId
    ) public view override returns (address, uint16) {
        RoyaltyInfo memory royaltyForToken = royaltyInfoForToken[_tokenId];

        return
            royaltyForToken.recipient == address(0)
                ? (royaltyRecipient, uint16(royaltyBps))
                : (royaltyForToken.recipient, uint16(royaltyForToken.bps));
    }

    /// @dev EIP-2981 compliance
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    )
        external
        view
        virtual
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        (address recipient, uint256 bps) = getRoyaltyInfoForToken(tokenId);
        receiver = recipient;
        royaltyAmount = (salePrice * bps) / MAX_BPS;
    }

    function _addToken(
        uint256 _tokenId,
        string memory _uri
    ) internal returns (uint256) {
        uint256 tokenIdToAdd;

        if (_tokenId == type(uint256).max) {
            tokenIdToAdd = nextTokenIdToMint;
            nextTokenIdToMint += 1;
            _tokenUris[tokenIdToAdd] = _uri;
        }

        return tokenIdToAdd;
    }

    function addNewToken(
        uint256 _price,
        string calldata _uri,
        uint256 _totalSupply
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256) {
        // each token should be defined as struct
        uint256 _tokenId;
        _tokenId = _addToken(MAX_INT, _uri);

        nfts[_tokenId].price = _price;
        nfts[_tokenId].tokenURI = _uri;
        nfts[_tokenId].maxSupply = _totalSupply;

        emit TokenCreated(_tokenId);
        return _tokenId;
    }

    function mint(
        uint256 _tokenId,
        uint256 _quantity
    ) external payable override {
        // ! Check max supply parameter for this mint function
        require(_tokenId > 0, "Invalid token id");
        if (_tokenId <= initialSupply) {
            require(
                msg.value >= (initialPrices[_tokenId - 1] * _quantity),
                "Insufficient amount."
            );
        } else {
            require(
                msg.value >= (nfts[_tokenId].price * _quantity),
                "Insufficient amount."
            );
        }

        _mint(msg.sender, _tokenId, _quantity, bytes(""));
    }

    function tokenURI(uint256 _tokenId) public view returns (string memory) {
        if (bytes(_tokenUris[_tokenId]).length > 0) return _tokenUris[_tokenId];
        else {
            string memory baseURI_ = baseURI;
            return
                bytes(baseURI_).length > 0
                    ? string(abi.encodePacked(baseURI_, _tokenId.toString()))
                    : "";
        }
    }

    function withdrawToken(
        address _receiver,
        address _token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {}

    function withdraw(address _receiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // 1️⃣ Implement commissions while withdraw
        // 2️⃣ Send remaining to receiver address
        uint256 balance = address(this).balance;

        address _feeRecipient;
        uint256 _feeBps;

        (_feeRecipient, _feeBps) = _getPlatformFeeInfo();
        //calculate fees here
        uint256 _salesFee = calculateFee(balance, _feeBps);
        console.log("_salesFee: ", _salesFee);

        payable(_feeRecipient).transfer(_salesFee);
        payable(_receiver).transfer(balance - _salesFee);

        // ! Transfer whole balance from this ⚠️ if discount is applied
        // payable(_receiver).transfer(balance);
    }

    ///     =====   Platform fees       ======
    function _getPlatformFeeInfo() public view returns (address, uint256) {
        IPlatformFees platformFees = IPlatformFees(platformFeeManager);
        return platformFees.getPlatformFeeInfo();
    }

    ///     =====   Library              =====
    function calculateFee(
        uint256 value,
        uint256 fee
    ) public pure returns (uint256) {
        return value.div(1e3).mul(fee).div(10);
    }

    ///     =====   Low-level overrides  =====

    /// @dev Lets a token owner burn the tokens they own (i.e. destroy for good)
    function burn(address account, uint256 id, uint256 value) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved."
        );

        _burn(account, id, value);
    }

    /// @dev Lets a token owner burn multiple tokens they own at once (i.e. destroy for good)
    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved."
        );

        _burnBatch(account, ids, values);
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        // if transfer is restricted on the contract, we still want to allow burning and minting
        if (
            isSoulbound &&
            !hasRole(TRANSFER_ROLE, address(0)) &&
            from != address(0) &&
            to != address(0)
        ) {
            require(
                hasRole(TRANSFER_ROLE, from) || hasRole(TRANSFER_ROLE, to),
                "restricted to TRANSFER_ROLE holders."
            );
        }

        if (isTimebound && from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                require(
                    !hasExpired(ids[i]),
                    "Time bounding period is expired."
                );
            }
        }

        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 _totalSupply = totalSupply[ids[i]];
                if (ids[i] > initialSupply) {
                    require(
                        _totalSupply + amounts[i] <= nfts[ids[i]].maxSupply,
                        "Overflow max supply"
                    );
                } else {
                    require(
                        _totalSupply + amounts[i] <=
                            initialMaxSupplies[ids[i] - 1],
                        "Overflow max supply"
                    );
                }

                if (_totalSupply == 0 && isTimebound)
                    UpdateTokenValidity(ids[i]);
                totalSupply[ids[i]] += amounts[i];
            }
        }

        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                totalSupply[ids[i]] -= amounts[i];
            }
        }
    }

    /// @dev See {ERC1155-setApprovalForAll}
    function setApprovalForAll(
        address operator,
        bool approved
    )
        public
        override(ERC1155Upgradeable, IERC1155Upgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        public
        override(ERC1155Upgradeable, IERC1155Upgradeable)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        public
        override(ERC1155Upgradeable, IERC1155Upgradeable)
        onlyAllowedOperator(from)
    {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /// @dev Returns whether operator restriction can be set in the given execution context.
    function _canSetOperatorRestriction()
        internal
        virtual
        override
        returns (bool)
    {
        return hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(
            AccessControlEnumerableUpgradeable,
            IERC165Upgradeable,
            ERC1155Upgradeable
        )
        returns (bool)
    {
        return
            super.supportsInterface(interfaceId) ||
            interfaceId == type(IERC2981Upgradeable).interfaceId;
    }

    function canSetValidity() internal view override returns (bool) {
        return _msgSender() == owner();
    }
}
