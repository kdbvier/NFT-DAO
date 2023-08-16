// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "./extension/interface/IDiscount.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/MinimalForwarderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "./CreatorDAO.sol";
import "./lib/Base64.sol";
import "./lib/Config.sol";
import "./operator-filter-registry/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import "./rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";
import "./rarible/royalties/contracts/LibPart.sol";
import "./rarible/royalties/contracts/LibRoyaltiesV2.sol";
import "./extension/TimeboundToken.sol";
import "./interfaces/IERC5192.sol";


// TODO Perform all fundamental changes to this
contract MembershipCollection is
    Initializable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    ERC2771ContextUpgradeable,
    RoyaltiesV2Impl,
    DefaultOperatorFiltererUpgradeable,
    TimeboundToken,
    IERC5192
{
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;
    using Counters for Counters.Counter;

    bool private isLocked;

    error ErrLocked();
    error ErrNotFound();

    // define counter here
    Counters.Counter private _tokenIds;
    uint16 constant DEFAULT_ROYALTIES_BASIS = 10000; // 10% default
    uint256 constant DEFAULT_PERCENTAGE = 1000;

    // Mapping of individually frozen tokens
    mapping(uint256 => bool) public freezeTokenUris;
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;
    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;
    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    struct tier {
        uint256 floorPrice;
        uint256 totalSupply;
        bool isSet;
    }

    mapping(bytes32 => tier) private TierInfo;
    mapping(bytes32 => uint256) public _suppliedTokens; // tier to supply

    string public baseURI;

    bool public royaltiesEnabled;
    address public royaltiesAddress;
    uint256 public royaltiesBasisPoints;
    // address private decirContract;
    // address private discountContract;

    bytes32 public merkleRoot;

    event PermanentURI(string _value, uint256 indexed _id); // https://docs.opensea.io/docs/metadata-standards
    event PermanentURIGlobal();
    event TokenMinted(uint256 tokenId, string tokenURI);
    event RoyaltyAddressUpdated(address royaltiesSplitter);
    event MerkleRootUpdated(bytes32 root);
    event TierConfigured(bool status);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(MinimalForwarderUpgradeable _minimalForwarder)
        ERC2771ContextUpgradeable(address(_minimalForwarder))
    {}

    function initialize(
        Config.CollectionProxy memory _config
    ) public initializer {
        __Ownable_init();

        __ERC721_init(
            _config.collection.deployConfig.name,
            _config.collection.deployConfig.symbol
        );
        _transferOwnership(_config.collection.deployConfig.owner);

        /// @dev: opensea onchain royalty enforcement 
        __DefaultOperatorFilterer_init();

        royaltiesEnabled = true;
        royaltiesBasisPoints = (_config.collection.runConfig.royaltiesBps <= 0)
            ? DEFAULT_PERCENTAGE
            : _config.collection.runConfig.royaltiesBps;
        royaltiesAddress = _config.collection.runConfig.royaltyAddress;

        baseURI = _config.collection.runConfig.baseURI;
        // ! This is disabled because fee waiver will be added to Decir membership pass
        // discountContract = _config.discount;
        // decirContract = _config.decirTreasury;
        isLocked = _config.isLocked;

        if(_config.collection.runConfig.validity > 0) {
            SetValidity(_config.collection.runConfig.validity);
        }
    }

    modifier checkLock() {
        if (isLocked) revert ErrLocked();
        _;
    }

    function locked(uint256 _tokenId) external view returns (bool) {
        uint256 tokenId = _tokenIds.current();
        if (tokenId >= _tokenId) revert ErrNotFound();
        return isLocked;
    }

    function setTiers(Config.TierConfig[] memory _tierConfigs)
        public
        onlyOwner
    {
        for (
            uint256 tierIndex = 0;
            tierIndex < _tierConfigs.length;
            tierIndex++
        ) {
            bytes32 _givenTier = sha256(
                abi.encode(_tierConfigs[tierIndex].tierId)
            );
            // require(!TierInfo[_givenTier].isSet, "Membership: Tier Information already exists");

            setTierInfo(
                _givenTier,
                _tierConfigs[tierIndex].floorPrice,
                _tierConfigs[tierIndex].totalSupply
            );
        }

        emit TierConfigured(true); // TODO this will be optimized
    }

    function setTierInfo(
        bytes32 _givenTier,
        uint256 _floorPrice,
        uint256 _totalSupply
    ) internal {
        TierInfo[_givenTier].floorPrice = _floorPrice;
        TierInfo[_givenTier].totalSupply = _totalSupply;
        TierInfo[_givenTier].isSet = true;
    }

    function checkTierStatus(string memory _tierId) public view returns (bool) {
        bytes32 _givenTier = sha256(abi.encode(_tierId));
        return (_suppliedTokens[_givenTier] < TierInfo[_givenTier].totalSupply);
    }

    function GetTierStatus(string memory _tierId)
        public
        view
        returns (uint256)
    {
        bytes32 _givenTier = sha256(abi.encode(_tierId));
        return _suppliedTokens[_givenTier];
    }

    function getTotalSupply(string memory _tierId)
        public
        view
        returns (uint256)
    {
        bytes32 _givenTier = sha256(abi.encode(_tierId));
        return TierInfo[_givenTier].totalSupply;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable)
        returns (bool)
    {
        return
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            interfaceId == type(IERC2981Upgradeable).interfaceId ||
            interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES ||
            interfaceId == type(IERC5192).interfaceId;
    }

    // // TODO this needs custom ownership checking
    // function setRoyaltyAddress(address _royaltyReceiver) public {
    //     royaltiesAddress = _royaltyReceiver;
    //     emit RoyaltyAddressUpdated(royaltiesAddress);
    // }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address, uint256)
    {
        return (
            royaltiesAddress,
            (royaltiesBasisPoints * salePrice) / DEFAULT_ROYALTIES_BASIS
        );
    }

    function contractURI() external view returns (string memory) {
        // address _royaltiesAddress = address(0);
        if (royaltiesEnabled) {
            string memory json = Base64.encode(
                bytes(
                    string(
                        abi.encodePacked(
                            // solium-disable-next-line quotes
                            '{"seller_fee_basis_points": ', // solhint-disable-line quotes
                            royaltiesBasisPoints.toString(),
                            // solium-disable-next-line quotes
                            ', "fee_recipient": "', // solhint-disable-line quotes
                            uint256(uint160(royaltiesAddress)).toHexString(20),
                            // solium-disable-next-line quotes
                            '"}' // solhint-disable-line quotes
                        )
                    )
                )
            );

            string memory output = string(
                abi.encodePacked("data:application/json;base64,", json)
            );

            return output;
        }

        return string(abi.encodePacked("data:application/json;base64,", ""));
    }

    function _baseURI()
        internal
        view
        virtual
        override(ERC721Upgradeable)
        returns (string memory)
    {
        return baseURI;
    }

    function setRoyalties(
        uint256 _tokenId,
        address payable _royaltiesReceipientAddress,
        uint96 _percentageBasisPoints
    ) public {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesReceipientAddress;
        _saveRoyalties(_tokenId, _royalties);
    }

    /*
        https://levelup.gitconnected.com/how-to-mint-100-000-nfts-for-free-62d83888ff6
    */
    function mintToCaller(
        address caller,
        string memory tokenURI,
        string memory _tier
    ) public payable returns (uint256) {
        bytes32 _tierId = sha256(abi.encode(_tier));
        require(TierInfo[_tierId].isSet, "Membership: Tier information not set");
        require(
            TierInfo[_tierId].totalSupply - 1 >= _suppliedTokens[_tierId],
            "Membership: Sold out."
        );
        require(
            TierInfo[_tierId].floorPrice == msg.value,
            "Membership: Price does not match"
        );

        _suppliedTokens[_tierId] += 1;

        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();

        _safeMint(caller, tokenId);
        _setTokenURI(tokenId, tokenURI);

        if (royaltiesAddress != address(0x0)) {
            // ?  This should be working with raraible for each of the token minted
            setRoyalties(
                tokenId,
                payable(royaltiesAddress),
                uint96(royaltiesBasisPoints)
            );
        }

        // Set validity for the token
        UpdateTokenValidity(tokenId);

        emit TokenMinted(tokenId, tokenURI);
        return tokenId;
    }


    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;

        // FIXME: Discount calculations will be used from Decir membership pass
        // IPrimarySaleFees _decir = IPrimarySaleFees(decirContract);
        // IDiscount _discount = IDiscount(discountContract);
        // bool isDiscountApplied = _discount.isDiscountApplied(owner(), 0);

        // uint256 _fees;
        // address _feeRecipient;
        // (_feeRecipient, _fees) = _decir.primarySaleFeeRecipient();

        // if (isDiscountApplied) {
        //     payable(_msgSender()).transfer(address(this).balance);
        // } else {
        //     uint256 commission = calculateFee(balance, _fees);

        //     payable(_feeRecipient).transfer(commission);
        //     payable(_msgSender()).transfer((balance - commission));
        // }

        payable(_msgSender()).transfer(balance);

        // ! TODO: create event when required
    }

    function calculateFee(uint256 value, uint256 fee)
        internal
        pure
        returns (uint256)
    {
        uint256 result = SafeMath.div(
            SafeMath.mul(SafeMath.div(value, 1e3), fee),
            10
        );
        return result;
    }

    function whitelistedMint(
        string memory tokenURI,
        bytes32[] calldata _merkleProof
    ) public payable returns (uint256) {
        require(
            checkValidity(_merkleProof),
            "MINT_ERROR: Should be whitelisted user."
        );

        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();

        _safeMint(_msgSender(), tokenId);
        _setTokenURI(tokenId, tokenURI);

        emit TokenMinted(tokenId, tokenURI);
        return tokenId;
    }

    function updateTokenUri(
        uint256 _tokenId,
        string memory _tokenUri,
        bool _isFreezeTokenUri
    ) public onlyOwner {
        require(
            _exists(_tokenId),
            "NFT: update URI query for nonexistent token"
        );
        // require(metadataUpdatable, "NFT: Token uris are frozen globally");
        require(freezeTokenUris[_tokenId] != true, "NFT: Token is frozen");
        require(
            _isFreezeTokenUri || (bytes(_tokenUri).length != 0),
            "NFT: Either _tokenUri or _isFreezeTokenUri=true required"
        );

        if (bytes(_tokenUri).length != 0) {
            require(
                keccak256(bytes(tokenURI(_tokenId))) !=
                    keccak256(
                        bytes(string(abi.encodePacked(_baseURI(), _tokenUri)))
                    ),
                "NFT: New token URI is same as updated"
            );
            _setTokenURI(_tokenId, _tokenUri);
        }
        if (_isFreezeTokenUri) {
            freezeTokenUris[_tokenId] = true;
            emit PermanentURI(tokenURI(_tokenId), _tokenId);
        }
    }

    function transferByOwner(address _to, uint256 _tokenId) public onlyOwner {
        // require(tokensTransferable, "NFT: Transfers by owner are disabled");
        _safeTransfer(owner(), _to, _tokenId, "");
    }

    function burn(uint256 _tokenId) public {
        // require(tokensBurnable, "NFT: tokens burning is disabled");
        require(_exists(_tokenId), "Burn for nonexistent token");
        require(
            ERC721Upgradeable.ownerOf(_tokenId) == owner(),
            "NFT: tokens may be burned by owner only"
        );
        _burn(_tokenId);
    }

    function totalSupply() public view virtual returns (uint256) {
        return _allTokens.length;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        virtual
        returns (uint256)
    {
        require(index < balanceOf(owner), "ERC721: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    function tokenByIndex(uint256 index) public view virtual returns (uint256) {
        require(index < totalSupply(), "ERC721: global index out of bounds");
        return _allTokens[index];
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize // ! This should be read and changed properly @subash
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721Upgradeable.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId)
        private
    {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721Upgradeable.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }

    //
    function setApprovalForAll(address operator, bool approved)
        public
        override
        checkLock
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId)
        public
        override
        checkLock
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override checkLock onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override checkLock onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override checkLock onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    // This function is used to verify whitelisting of users
    function checkValidity(bytes32[] calldata _merkleProof)
        public
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Whitelist: Address not whitelisted for minting"
        );
        return true;
    }

    function _msgSender()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function canSetValidity() internal override view returns (bool) {
        return _msgSender() == owner();
    }
}
