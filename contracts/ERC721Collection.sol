// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


// import "./extension/interface/IDiscount.sol";
import "./extension/interface/IRoyalty.sol";
 import "./lib/FeeCalculator.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/MinimalForwarderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// import "./lib/FeeCalculator.sol";
import "./lib/Base64.sol";
import "./lib/Config.sol"; 
import "./operator-filter-registry/upgradeable/DefaultOperatorFiltererUpgradeable.sol"; // * opensea enforcement
// * * Rarible royalties
import "./rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol"; 
import "./rarible/royalties/contracts/LibPart.sol";
import "./rarible/royalties/contracts/LibRoyaltiesV2.sol";
// import "./extension/interface/IPrimarySaleFees.sol";

// Add granular roles here
contract ERC721Collection is 
    Initializable,
    IRoyalty,
    ERC721URIStorageUpgradeable, 
    OwnableUpgradeable, 
    ERC2771ContextUpgradeable,
    RoyaltiesV2Impl,
    DefaultOperatorFiltererUpgradeable
{
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;
    using StringsUpgradeable for uint128;
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    bytes32 private constant MODULE_TYPE = bytes32("Decir721Token");
    uint256 private constant VERSION = 1;

    uint16 constant MAX_BPS = 10_000;

    // define counter here
    Counters.Counter private _tokenIds;

    uint256 private MAX_SUPPLY;
    uint256 private FLOOR_PRICE;


    uint128 public royaltyBps;

    string public baseURI;
    address public royaltyRecipient;
    address private decirContract;
    address private discountContract;
    bool private isActive;
    bool private isPresaleActive;
     
    mapping(bytes32 => uint256) public _suppliedTokens; // tier to supply
    mapping(uint256 => bool) public freezeTokenUris;
    mapping(uint256 => RoyaltyInfo) private royaltyInfoForToken;
    // mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    // mapping(uint256 => uint256) private _ownedTokensIndex;
    // mapping(uint256 => uint256) private _allTokensIndex;
    uint256[] private _allTokens;

    event PermanentURI(string _value, uint256 indexed _id); // https://docs.opensea.io/docs/metadata-standards
    event TokenMinted(uint256 tokenId, string tokenURI);
    event RoyaltyAddressUpdated(address);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        MinimalForwarderUpgradeable _minimalForwarder
        
    ) ERC2771ContextUpgradeable(address(_minimalForwarder)) {
        // fee recipient should be set once during contract deployment
        
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        address _creator,
        string memory _tokenBaseURI,
        uint128 _royaltyBps,
        address _royaltyRecipient,
        uint256 _maxSupply,
        uint256 _floorPrice
        // address _decirContract,
        // address _platformDiscount
    )  initializer public  {
        __Ownable_init();
        __ERC721_init(_name, _symbol);
        _transferOwnership(_creator);

        // * opensea royalties enforcement
        __DefaultOperatorFilterer_init();

        // Royalties are always enabled - so commenting this line 
        royaltyBps = _royaltyBps;
        royaltyRecipient = _royaltyRecipient;

        MAX_SUPPLY = _maxSupply;
        FLOOR_PRICE = _floorPrice;

        _baseTokenURI = _tokenBaseURI;

        // decirContract = _decirContract;
        // discountContract = _platformDiscount;

        // _setupContractURI(_contractURI);
        // _setupPrimarySaleRecipient(_msgSender(), _floorPrice); // ! This is not required
        // Sales values are already stored in the contract 
    }

    modifier callerIsUser() {
        require(tx.origin == _msgSender(), "The caller is another contract");
        _;
    }

    function setActive(bool _isActive) external onlyOwner {
        isActive = _isActive;
    }

    function preSaleActive(bool _isActive) external onlyOwner {
        isPresaleActive = _isActive;
    }

    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
      return _baseTokenURI;
    }
  
    function setBaseURI(string calldata _baseURI) external onlyOwner {
      _baseTokenURI = _baseURI;
    }

    function contractType() external pure returns (bytes32) {
        return MODULE_TYPE;
    }

    /// @dev Returns the version of the contract.
    function contractVersion() external pure returns (uint8) {
        return uint8(VERSION);
    }

    function floorPrice() public view returns (uint256) {
        return FLOOR_PRICE;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            interfaceId == type(IERC2981Upgradeable).interfaceId ||
            interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES;
    }

    function setDefaultRoyaltyInfo(address _royaltyRecipient, uint256 _royaltyBps)
    external
    onlyOwner
    {
        require(_royaltyBps <= MAX_BPS, "exceed royalty bps");

        royaltyRecipient = _royaltyRecipient;
        royaltyBps = uint128(_royaltyBps);

        emit DefaultRoyalty(_royaltyRecipient, _royaltyBps);
    }

    /// @dev Lets a module admin set the royalty recipient for a particular token Id.
    function setRoyaltyInfoForToken(
        uint256 _tokenId,
        address _recipient,
        uint256 _bps
    ) external onlyOwner {
        require(_bps <= MAX_BPS, "exceed royalty bps");

        royaltyInfoForToken[_tokenId] = RoyaltyInfo({ recipient: _recipient, bps: _bps });

        emit RoyaltyForToken(_tokenId, _recipient, _bps);
    }

    function contractURI() public view returns (string memory) {
        // address _royaltiesAddress = address(0);
        // if (royaltiesEnabled) {
            string memory json = Base64.encode(
                bytes(
                    string(
                        abi.encodePacked(
                            // solium-disable-next-line quotes
                            '{"seller_fee_basis_points": ', // solhint-disable-line quotes
                            royaltyBps.toString(),
                            // solium-disable-next-line quotes
                            ', "fee_recipient": "', // solhint-disable-line quotes
                            uint256(uint160(royaltyRecipient)).toHexString(20),
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
        // }

        // return string(abi.encodePacked("data:application/json;base64,", ""));
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        virtual
        returns (address receiver, uint256 royaltyAmount)
    {
        (address recipient, uint256 bps) = getRoyaltyInfoForToken(tokenId);
        receiver = recipient;
        royaltyAmount = (salePrice * bps) / MAX_BPS;
    }

    function setRoyalties(
        uint _tokenId,
        address payable _royaltiesReceipientAddress,
        uint96 _percentageBasisPoints
    ) public {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesReceipientAddress;
        _saveRoyalties(_tokenId, _royalties);
    }

    function balance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() public onlyOwner {
        uint256 balance_ = address(this).balance;
        // IPrimarySaleFees _decir = IPrimarySaleFees(decirContract);
        // IDiscount _discount = IDiscount(discountContract);
        // bool isDiscountApplied = _discount.isDiscountApplied(owner(), 0);

        // uint256 _fees;
        // address _feeRecipient;
        // (_feeRecipient, _fees) = _decir.primarySaleFeeRecipient();

        // if(isDiscountApplied) {
        //     payable(_msgSender()).transfer(address(this).balance);
        // } else {
        //     uint256 commission = calculateFee(balance_, _fees);

        //     payable(_feeRecipient).transfer(commission);
        //     payable(_msgSender()).transfer((balance_ - commission));
        // }

        payable(_msgSender()).transfer((balance_));
        // ! TODO: create event when required
    }

    function calculateFee(uint256 value, uint256 fee) public pure returns(uint256) {
        return value.div(1e3).mul(fee).div(10);
    }


    function mintToCaller(
        address caller,
        string memory tokenURI
    ) payable public  returns (uint256) {
            // TODO should be enabled when releasing this contract
        // TODO Check for max supply here
        require(totalSupply() <= MAX_SUPPLY, "PRIMARY SALE completed.");
        require(
                msg.value >= FLOOR_PRICE,
                "ERROR: Price must be equal to primary mint price"
            );

        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();

        _safeMint(caller, tokenId);
        _setTokenURI(tokenId, tokenURI);

        _allTokens.push(tokenId);
        
        if(royaltyRecipient != address(0x0)) {
            setRoyalties(tokenId, payable(royaltyRecipient), uint96(royaltyBps));
        }

        emit TokenMinted(tokenId, tokenURI);
        return tokenId;
    }


    // TODO move this to separate interface as internal function 
    function updateTokenUri(
        uint256 _tokenId,
        string memory _tokenUri,
        bool _isFreezeTokenUri
    ) public {
        require(
            _exists(_tokenId),
            "NFT: update URI query for nonexistent token"
        );
        // require(metadataUpdatable, "NFT: Token uris are frozen globally");
        require(freezeTokenUris[_tokenId] != true, "NFT: Token is frozen");
        require(ownerOf(_tokenId) == _msgSender(), "NFT: Should be owner of this token");
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
            _setTokenURI(_tokenId, _tokenUri); // ! FAULT: only with uri storage
        }
        if (_isFreezeTokenUri) {
            freezeTokenUris[_tokenId] = true;
            emit PermanentURI(tokenURI(_tokenId), _tokenId);
        }
    }

    function transferByOwner(address _to, uint256 _tokenId)
        public onlyOwner
    {
        _safeTransfer(owner(), _to, _tokenId, "");
    }

    function burn(uint256 _tokenId) public  {
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

    function getDefaultRoyaltyInfo() external view returns (address, uint16) {
        return (royaltyRecipient, uint16(royaltyBps));
    }

    /// @dev Returns the royalty recipient for a particular token Id.
    function getRoyaltyInfoForToken(uint256 _tokenId) public view returns (address, uint16) {
        RoyaltyInfo memory royaltyForToken = royaltyInfoForToken[_tokenId];

        return
            royaltyForToken.recipient == address(0)
                ? (royaltyRecipient, uint16(royaltyBps))
                : (royaltyForToken.recipient, uint16(royaltyForToken.bps));
    }


    /*
        Opensea filter overrides
    */

    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /*
        Primary sale settings
    */

    // TODO must check if current context can set primary sale recipient
    function _canSetPrimarySaleRecipient() internal view virtual returns (bool) {
        return _msgSender() == owner();
    }

    // TODO must check if current context can set contract uri
    // function _canSetContractURI() internal view virtual override returns (bool) {
    //     return _msgSender() == owner();
    // }


    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns(address) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }
}
