// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./interfaces/IERC5192.sol";

contract DecirMembership is ERC1155, IERC5192 {
    bool private isLocked;

    error ErrLocked();

    struct TokenInfo {
        string name;
        uint256 supply;
    }

    address owner;

    string public contractURI_;

    mapping(uint256 => TokenInfo) tokens;
    constructor(
        string memory _baseURI,
        string memory _contractURI,
        bool _isLocked
    ) ERC1155(_baseURI) {
        contractURI_ = _contractURI;
        owner = msg.sender;
        isLocked = _isLocked;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Membership: Only owner can add new tokens");
        _;
    }

    modifier checkLock() {
        if (isLocked) revert ErrLocked();
        _;
    }

    // Dynamically add number of tokens
    function addToken(string calldata _name, uint256 _tokenId, uint256 _supply) public onlyOwner  {
        // mapping(uint256 => uint256) memory _tokenSupply;
        tokens[_tokenId] = TokenInfo(_name, _supply);
    }

    function mint(address _to, uint256 _tokenId, uint256 _quantity) public onlyOwner {
        _mint(_to, _tokenId, _quantity, "");
    }

    // contractURI
    function contractURI() public view returns (string memory) {
        return contractURI_;
    }

    function locked(uint256 tokenId) external view returns (bool) {
        return isLocked;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) public override checkLock {
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    function setApprovalForAll(address operator, bool approved)
        public
        override
        checkLock
    {
        super.setApprovalForAll(operator, approved);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IERC5192).interfaceId
        || super.supportsInterface(interfaceId);
    }

}