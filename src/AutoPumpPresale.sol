// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IAutoPumpPresale } from "./interfaces/IAutoPumpPresale.sol";

/**
 * @title AutoPumpPresale
 * @dev AutoPumpPresale is a base contract from
 * https://github.com/ConsenSysMesh/openzeppelin-solidity/blob/master/contracts/crowdsale/Crowdsale.sol
 * for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for AutoPumpPresale which is crowdsales. They are *not* intended to be modified / overriden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales
 */
contract AutoPumpPresale is Ownable, ReentrancyGuard, IAutoPumpPresale {
    /// @notice Withdrawal period days
    uint256 public constant WITHDRAWAL_PERIOD_DAYS = 69 days;

    /// @notice Withdrawal period days
    uint256 public constant LOCKUP_PERIOD_DAYS = 7 days;

    /// @notice Adjust based on your needs
    uint256 public constant PRECISION_MULTIPLIER = 1e2;

    /**
     * @dev The token being sold
     */
    ERC20 public token;

    /**
     * @dev Address where funds are collected
     */
    address public treasuryWallet;

    /**
     * @dev Fundraising goal: the target amount to be raised during the presale
     */
    uint256 public fundraisingGoal;

    /**
     * @dev Amount of wei raised
     */
    uint256 public raisedAmount;

    /**
     * @dev Presale to end
     */
    bool public presaleClosed = true;

    /**
     * @dev Time when presale closed
     */
    uint256 public closedPresaleTime;

    /**
     * @dev Rate for each token
     */
    uint256 public rate;

    mapping(address => BuyerInfo) public buyers;

    /**
     * @dev Constructor for initializing the AutoPumpPresale contract.
     * @param wallet_ Address where collected funds will be forwarded to
     * @param token_ Address of the token being sold
     * @param fundraisingGoal_ Target fundraising goal for the presale
     * @param rate_ Rate for each token
     */
    constructor(address wallet_, ERC20 token_, uint256 fundraisingGoal_, uint256 rate_) Ownable(msg.sender) {
        require(fundraisingGoal_ > 0, "Invalid Fundraising Goal");
        require(wallet_ != address(0), "Invalid Wallet");

        treasuryWallet = wallet_;
        token = token_;

        fundraisingGoal = fundraisingGoal_;
        rate = rate_;
    }

    // -----------------------------------------
    // IAutoPumpPresale external interface
    // -----------------------------------------
    /**
     * @dev receive function ***DO NOT OVERRIDE***
     */
    receive() external payable {
        _buyTokens(msg.sender);
    }

    /**
     * @dev See {IAutoPumpPresale-setToken}.
     */
    function setToken(address newToken_) external onlyOwner {
        require(newToken_ != address(0), "Invalid Token Address");

        emit TreasuryWalletUpdated(address(token), newToken_);

        token = ERC20(newToken_);
    }

    /**
     * @dev See {IAutoPumpPresale-setTreasuryWallet}.
     */
    function setTreasuryWallet(address newWallet_) external onlyOwner {
        require(newWallet_ != address(0), "Invalid Wallet Address");

        emit TreasuryWalletUpdated(treasuryWallet, newWallet_);

        treasuryWallet = newWallet_;
    }

    /**
     * @dev See {IAutoPumpPresale-openPresale}.
     */
    function openPresale() external onlyOwner {
        require(presaleClosed, "Presale already opened");
        presaleClosed = false;
        emit PresaleOpened();
    }

    /**
     * @dev See {IAutoPumpPresale-withdraw}.
     */
    function withdraw(address to_, uint256 amount_) external onlyOwner {
        token.transfer(to_, amount_);

        emit TokenWithdrawn(to_, amount_);
    }

    /**
     * @dev See {IAutoPumpPresale-closePresale}.
     */
    function closePresale() external onlyOwner {
        _closePresale();
    }

    /**
     * @dev See {IAutoPumpPresale-buyTokens}.
     */
    function buyTokens() external payable {
        _buyTokens(msg.sender);
    }

    /**
     * @dev See {IAutoPumpPresale-withdrawTokens}.
     */
    function withdrawTokens() external {
        require(presaleClosed, "Presale not closed yet");

        // Ensure the current time is at least 7 days after the presale closed
        require(block.timestamp >= closedPresaleTime + LOCKUP_PERIOD_DAYS, "Lockup period not ended");

        uint256 eligibleTokens = calculateEligibleTokens(msg.sender);
        BuyerInfo storage buyer = buyers[msg.sender];

        require(eligibleTokens > 0, "No tokens available for withdraw");

        buyer.totalTokensWithdrawn += eligibleTokens;
        token.transfer(msg.sender, eligibleTokens);
        emit TokenWithdrawn(msg.sender, eligibleTokens);
    }

    /**
     * @dev See {IAutoPumpPresale-getTokenBalance}.
     */
    function getTokenBalance(address buyer_) external view returns (uint256) {
        return buyers[buyer_].tokenBalance;
    }

    function getTotalTokensWithdrawn(address buyer_) external view returns (uint256) {
        return buyers[buyer_].totalTokensWithdrawn;
    }

    function calculateEligibleTokens(address buyer_) public view returns (uint256) {
        BuyerInfo storage buyer = buyers[buyer_];

        if (!presaleClosed || buyer.tokenBalance == 0 || closedPresaleTime + LOCKUP_PERIOD_DAYS > block.timestamp) {
            return 0; // No tokens can be withdrawn if the presale hasn't closed or nothing was purchased.
        }

        uint256 secondsSinceClosure = block.timestamp - (closedPresaleTime + LOCKUP_PERIOD_DAYS);
        uint256 eligibleTokens = (buyer.tokenBalance * secondsSinceClosure) / WITHDRAWAL_PERIOD_DAYS;

        // Ensure we don't exceed the total owned.
        uint256 totalEligible = eligibleTokens > buyer.tokenBalance ? buyer.tokenBalance : eligibleTokens;
        return totalEligible - buyer.totalTokensWithdrawn;
    }

    // -----------------------------------------
    // Internal interface (extensible)
    // -----------------------------------------
    /**
     * @dev See {IAutoPumpPresale-buyTokens} but this funtion is an internal version.
     */
    function _buyTokens(address beneficiary_) internal nonReentrant {
        require(!presaleClosed, "Presale is closed");

        uint256 acceptedAmount = msg.value;

        require(acceptedAmount >= 0.5 ether, "Minimum buy amount 0.5 ETH");

        if (raisedAmount + acceptedAmount > fundraisingGoal) {
            uint256 excess = (raisedAmount + acceptedAmount) - fundraisingGoal; // Calculate excess correctly
            acceptedAmount = msg.value - excess; // Adjust acceptedAmount to exclude excess

            // Immediately refund excess funds to the sender.
            (bool refundSuccess, ) = payable(msg.sender).call{ value: excess }("");
            require(refundSuccess, "Refund failed");
        }

        // update state
        buyers[beneficiary_].tokenBalance += _getTokenAmount(acceptedAmount);

        raisedAmount += acceptedAmount;

        if (raisedAmount >= fundraisingGoal) {
            _closePresale();
        }

        emit TokenPurchase(msg.sender, acceptedAmount);

        // Forward Funds to treasury wallet
        (bool sent, ) = payable(treasuryWallet).call{ value: acceptedAmount }("");
        require(sent, "Failed to send Accepted Wei");
    }

    /**
     * @dev See {IAutoPumpPresale-closePresale} but this funtion is an internal version.
     */
    function _closePresale() internal {
        require(!presaleClosed, "Presale already closed");
        presaleClosed = true;
        closedPresaleTime = block.timestamp;
        emit PresaleClosed();
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param weiAmount_ Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 weiAmount_) internal view returns (uint256) {
        return (weiAmount_ * rate) / PRECISION_MULTIPLIER;
    }
}
