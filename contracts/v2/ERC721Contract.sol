//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/token/ITokenERC721.sol";

import "../interfaces/IDecirContract.sol";
import "../extension/interface/IPrimarySale.sol";
import "../extension/interface/IPlatformFees.sol";
import "../extension/interface/IRoyalty.sol";
import "../extension/interface/IOwnable.sol";

// Core library
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

// Signature
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";

// Meta transactions
// import "../openzeppelin-presets/metatx/ERC2771ContextUpgradeable.sol";

// Access Control + security
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// utilities
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";

// Math Utils
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../extension/DefaultOperatorFiltererUpgradeable.sol";

// Timebond
import "../extension/TimeboundToken.sol";

// Configuration
import "../lib/Config.sol";

contract ERC721Contract is
    Initializable,
    IDecirContract,
    IOwnable,
    IRoyalty,
    IPrimarySale,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    OwnableUpgradeable,
    MulticallUpgradeable,
    AccessControlEnumerableUpgradeable,
    DefaultOperatorFiltererUpgradeable,
    ERC721EnumerableUpgradeable,
    ITokenERC721,
    TimeboundToken
{
    using StringsUpgradeable for uint256;
    using SafeMath for uint256;

    bytes32 private constant MODULE_TYPE = bytes32("ERC721Token");
    uint256 private constant VERSION = 2;

    // ! DEFINE TYPE HASH HERE FOR VARIOUS FUNCTIONS

    uint256 private constant MAX_BPS = 10_000;

    // bytes32 private constant  DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 private constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    // Contract-level metadata
    string public baseURI;

    string private _contractURI;

    /// @dev Owner of the contract (purpose: OpenSea compatibility, etc.)
    address private _owner;

    /// @dev The token ID of the next token to mint.
    uint256 public nextTokenIdToMint;

    /// @dev The adress that receives all primary sales value.
    address public primarySaleRecipient; // ! Why this is override check against the interface

    /// @dev The adress that manages all platform fees value.
    address private platformFeeManager;

    /// @dev The recipient of who gets the royalty.
    address private royaltyRecipient;

    /// @dev The percentage of royalty how much royalty in basis points.
    uint128 private royaltyBps;

    /// @dev The % of primary sales collected by the contract as fees.
    uint128 private platformFeeBps;

    /// @dev Soulbound standard
    bool public isSoulbound;

    /// @dev Timebound standard
    bool public isTimebound;

    uint256 public floorPrice;
    uint256 public maxSupply;

    uint256 private addedTokens;

    mapping(bytes32 => bool) private minted;
    mapping(uint256 => string) private uri;
    mapping(uint256 => string) private updatedTokens;
    mapping(uint256 => uint256) private updatedTokenPrice;
    mapping(uint256 => RoyaltyInfo) private royaltyInfoForToken;

    event TokenCreated(uint256 tokenId);

    function initialize(
        Config.ERC721Params calldata params
    ) external initializer {
        __ReentrancyGuard_init();
        __EIP712_init("ERC721Token", "1");
        __Ownable_init();
        __ERC721_init(params.name, params.symbol);

        _transferOwnership(params.defaultAdmin);

        __DefaultOperatorFilterer_init();

        _setOperatorRestriction(true);
        royaltyRecipient = params.royaltyRecipient;
        royaltyBps = params.royaltyBps;

        primarySaleRecipient = params.primarySaleRecipient;

        baseURI = params.baseURI;
        floorPrice = params.floorPrice;
        maxSupply = params.maxSupply; // ! When set this should be satisified

        // Add token cofiguration - initial supply for the drop
        addedTokens = params.initialSupply;

        /*
          ! Platform fee & recipient - Defined by Decir contract
        */

        // ! setup roles
        _setupRole(DEFAULT_ADMIN_ROLE, params.defaultAdmin);
        _contractURI = params.contractURI; // cannot be set by proxy factory during deployment
        _owner = params.defaultAdmin;

        // Setup platform fee manager
        platformFeeManager = params.platformFeeManager;
        isSoulbound = params.isSoulbound;
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

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        if (bytes(updatedTokens[tokenId]).length > 0)
            return updatedTokens[tokenId];
        else {
            string memory baseURI_ = baseURI;
            return
                bytes(baseURI_).length > 0
                    ? string(abi.encodePacked(baseURI_, tokenId.toString()))
                    : "";
        }
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

    function mint(uint256 _tokenId) external payable override {
        if (bytes(updatedTokens[_tokenId]).length > 0) {
            // Get price value from updated token price
            require(
                updatedTokenPrice[_tokenId] == msg.value,
                "Invalid token price added."
            );
        } else {
            require(floorPrice == msg.value, "Invalid token price.");
            nextTokenIdToMint += 1; /// @dev as minting is done from batch token setup - keeps track of how many tokens are minted
        }
        _mintTo(msg.sender, _tokenId);
    }

    // Only admin can call this function
    function addNewToken(
        uint256 _price,
        string calldata _uri
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256) {
        require(totalSupply() + addedTokens < maxSupply, "max supply reached.");
        require(bytes(_uri).length > 0, "empty uri.");

        /// @dev increament new token counter.
        // addedTokens = addedTokens + totalSupply();
        /// @dev add newly added token URI to mapping. If the supply is zero.
        addedTokens += 1;
        updatedTokens[addedTokens] = _uri;
        /// @dev update proce for newly added token giveb by adming
        updatedTokenPrice[addedTokens] = _price;
        // ! Should emit new event for this
        emit TokenCreated(addedTokens);
        return addedTokens; /// @dev return newly added tokenId
    }

    function _mintTo(address _to, uint256 _tokenId) internal returns (uint256) {
        require(_tokenId <= maxSupply, "cannot exceed maximum supply.");
        if (bytes(updatedTokens[_tokenId]).length > 0) {
            /// @dev update uri to be from
            uri[_tokenId] = updatedTokens[_tokenId];
        }
        if (isTimebound) UpdateTokenValidity(_tokenId);
        _safeMint(_to, _tokenId);
        emit TokenMinted(_to, _tokenId);
        return _tokenId;
    }

    function _mintTo(
        address to,
        string calldata _uri
    ) internal returns (uint256 tokenIdToMint) {
        tokenIdToMint = nextTokenIdToMint;
        nextTokenIdToMint += 1;

        require(bytes(_uri).length > 0, "empty uri.");
        uri[tokenIdToMint] = _uri;

        _safeMint(to, tokenIdToMint);

        emit TokensMinted(to, tokenIdToMint, _uri);
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

    /// @dev Burns `tokenId`. See {ERC721-_burn}.
    function burn(uint256 tokenId) public virtual {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721Burnable: caller is not owner nor approved"
        );
        _burn(tokenId);
    }

    /// @dev See {ERC721-_beforeTokenTransfer}.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override(ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);

        // if transfer is restricted on the contract, we still want to allow burning and minting
        if (
            isSoulbound &&
            !hasRole(TRANSFER_ROLE, address(0)) &&
            from != address(0) &&
            to != address(0)
        ) {
            require(
                hasRole(TRANSFER_ROLE, from) || hasRole(TRANSFER_ROLE, to),
                "restricted to TRANSFER_ROLE holders"
            );
        }
        if (isTimebound) {
            require(
                !hasExpired(tokenId),
                "Timebound Period is already expired."
            );
        }
    }

    /// @dev See {ERC721-setApprovalForAll}.
    function setApprovalForAll(
        address operator,
        bool approved
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    /// @dev See {ERC721-approve}.
    function approve(
        address operator,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    /// @dev See {ERC721-_transferFrom}.
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
    {
        super.transferFrom(from, to, tokenId);
    }

    /// @dev See {ERC721-_safeTransferFrom}.
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    /// @dev See {ERC721-_safeTransferFrom}.
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
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
            ERC721EnumerableUpgradeable,
            IERC165Upgradeable
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

    // function _msgSender()
    //     internal
    //     view
    //     virtual
    //     override(ContextUpgradeable, ERC2771ContextUpgradeable)
    //     returns (address sender)
    // {
    //     return ERC2771ContextUpgradeable._msgSender();
    // }

    // function _msgData()
    //     internal
    //     view
    //     virtual
    //     override(ContextUpgradeable, ERC2771ContextUpgradeable)
    //     returns (bytes calldata)
    // {
    //     return ERC2771ContextUpgradeable._msgData();
    // }
}
