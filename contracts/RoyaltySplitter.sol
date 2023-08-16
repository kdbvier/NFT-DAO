// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (finance/PaymentSplitter.sol)

pragma solidity ^0.8.0;

import "./extension/interface/IDiscount.sol";
import "./extension/interface/IDistributionFees.sol";
import "./interfaces/IDecirTreasury.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/MinimalForwarderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract RoyaltySplitter is Initializable, OwnableUpgradeable, ERC2771ContextUpgradeable
{
    using AddressUpgradeable for address;
    using SafeMath for uint256;

    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event ERC20PaymentReleased(
        IERC20Upgradeable indexed token,
        address to,
        uint256 amount
    );
    event PaymentReceived(address from, uint256 amount);
    event MembershipTokenAdded(address token);

    uint256 private _totalShares;
    uint256 private _totalReleased;

    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;

    // Contracts for managing and handling platform discounts 
    address decirContract;
    address discountContract;

    address constant private DEFAULT_TREASURY=address(0xc946076ef04CCbaE8E75679ec2a7278490F13960);

    mapping(IERC20Upgradeable => uint256) private _erc20TotalReleased;
    mapping(IERC20Upgradeable => mapping(address => uint256))
        private _erc20Released;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        MinimalForwarderUpgradeable _minimalForwarder
    ) ERC2771ContextUpgradeable(address(_minimalForwarder)) {
        
    }

    function initialize(
        uint256[] memory shares_, 
        address[] memory _receivers, 
        address _owner
    )
        public initializer
    {

        __Ownable_init();
        _transferOwnership(_owner);

        initializeSplitter(
            _receivers,
            shares_
        );

        // decirContract = _decirContract;
        // discountContract = _discountContract;
    }

    function initializeSplitter(
        address[] memory payees,
        uint256[] memory shares_
    ) internal {
        require(
            payees.length == shares_.length,
            "PaymentSplitter: payees and shares length mismatch"
        );
        require(payees.length > 0, "PaymentSplitter: no payees");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }
    }

    function updateShares(address[] memory payees, uint256[] memory shares_) public onlyOwner {
        _totalShares = 0; // reset total shares
        initializeSplitter(payees, shares_);
    }

    receive() external payable virtual {

        // IDistributionFees _decir = IDistributionFees(decirContract);
        // IDiscount _discount = IDiscount(discountContract);
        // bool isDiscoutApplied = _discount.isDiscountApplied(owner(), 1);

        // address _feeRecipient;
        // uint256 _feePercentage;
        
        // (_feeRecipient, _feePercentage) =  _decir.getDistributionFeeInfo();

        // if(!isDiscoutApplied) {
        //     uint256 commission = calculateFee(msg.value, _feePercentage);
        //     payable(_feeRecipient).transfer(commission);
        //     emit PaymentReceived(_msgSender(), msg.value);
        // }

        payable(owner()).transfer(msg.value);
        emit PaymentReceived(_msgSender(), msg.value);
    }

    /**
     * @dev Getter for the total shares held by payees.
     */
    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    /**
     * @dev Getter for the total amount of Ether already released.
     */
    function totalReleased() public view returns (uint256) {
        return _totalReleased;
    }

    /**
     * @dev Getter for the total amount of `token` already released. `token` should be the address of an IERC20Upgradeable
     * contract.
     */
    function totalReleasedToken(IERC20Upgradeable token)
        public
        view
        returns (uint256)
    {
        return _erc20TotalReleased[token];
    }

    /**
     * @dev Getter for the amount of shares held by an account.
     */
    function shares(address account) public view returns (uint256) {
        return _shares[account];
    }

    /**
     * @dev Getter for the amount of Ether already released to a payee.
     */
    function released(address account) public view returns (uint256) {
        return _released[account];
    }

    /**
     * @dev Getter for the amount of `token` tokens already released to a payee. `token` should be the address of an
     * IERC20Upgradeable contract.
     */
    function releasedToken(IERC20Upgradeable token, address account)
        public
        view
        returns (uint256)
    {
        return _erc20Released[token][account];
    }

    /**
     * @dev Getter for the address of the payee number `index`.
     */
    function payee(uint256 index) public view returns (address) {
        return _payees[index];
    }

    /**
     * @dev Getter for the amount of payee's releasable Ether.
     */
    function releasable(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased();
        return _pendingPayment(account, totalReceived, released(account));
    }

    /**
     * @dev Getter for the amount of payee's releasable `token` tokens. `token` should be the address of an
     * IERC20Upgradeable contract.
     */
    function releasableToken(IERC20Upgradeable token, address account)
        public
        view
        returns (uint256)
    {
        uint256 totalReceived = token.balanceOf(address(this)) +
            totalReleasedToken(token);
        return
            _pendingPayment(account, totalReceived, releasedToken(token, account));
    }


    /**
     * @dev Triggers a transfer to `account` of the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */

    function calculateFee(uint256 value, uint256 fee) public pure returns(uint256) {
        return value.div(1e3).mul(fee).div(10);
    }

    
    function release(address payable account) public virtual {
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");
        uint256 payment = releasable(account);

        require(payment != 0, "PaymentSplitter: account is not due payment");

        // _totalReleased is the sum of all values in _released.
        // If "_totalReleased += payment" does not overflow, then "_released[account] += payment" cannot overflow.
        _totalReleased += payment;

        unchecked {
            _released[account] += payment;
        }

        uint256 balance = payment;
        AddressUpgradeable.sendValue(account, balance);
        emit PaymentReleased(account, payment);
    }

    

    /**
     * @dev Triggers a transfer to `account` of the amount of `token` tokens they are owed, according to their
     * percentage of the total shares and their previous withdrawals. `token` must be the address of an IERC20Upgradeable
     * contract.
     */
    function releaseToken(IERC20Upgradeable token, address account) public virtual {
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");

        uint256 payment = releasableToken(token, account);

        require(payment != 0, "PaymentSplitter: account is not due payment");

        // _erc20TotalReleased[token] is the sum of all values in _erc20Released[token].
        // If "_erc20TotalReleased[token] += payment" does not overflow, then "_erc20Released[token][account] += payment"
        // cannot overflow.
        _erc20TotalReleased[token] += payment;
        unchecked {
            _erc20Released[token][account] += payment;
        }

        // TODO Implement discount here!!

        SafeERC20Upgradeable.safeTransfer(token, account, payment);
        emit ERC20PaymentReleased(token, account, payment);
    }

    /**
     * @dev internal logic for computing the pending payment of an `account` given the token historical balances and
     * already released amounts.
     */
    function _pendingPayment(
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private view returns (uint256) {
        uint256 totalClaimable = (totalReceived * _shares[account]) / _totalShares - alreadyReleased;
        return totalClaimable;
    }

    /**
     * @dev Add a new payee to the contract.
     * @param account The address of the payee to add.
     * @param shares_ The number of shares owned by the payee.
     */
    function _addPayee(address account, uint256 shares_) private {
        require(
            account != address(0),
            "PaymentSplitter: account is the zero address"
        );
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        // require(
        //     _shares[account] == 0,
        //     "PaymentSplitter: account already has shares"
        // );
        // If shares already exist 
        if(_shares[account] == 0) {
            _payees.push(account);    
        }
        _shares[account] = shares_;
        _totalShares = _totalShares + shares_;
        emit PayeeAdded(account, shares_);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[43] private __gap;

    function addPayee(address account_, uint256 shares_) public onlyOwner {
        _addPayee(account_, shares_);
    }

    function totalPayees() public view returns (uint256) {
        return _payees.length;
    }

    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns(address) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns(bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    } 
}