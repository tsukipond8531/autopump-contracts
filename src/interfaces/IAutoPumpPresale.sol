// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IAutoPumpPresale {
    /// @notice Represents a buyer's purchase information
    struct BuyerInfo {
        uint256 tokenBalance; //  Total tokens withdrawn after the withdrawal period starts
        uint256 totalTokensWithdrawn; //  Total tokens withdrawn after the withdrawal period starts
    }

    /**
     * Event for Closing Presale
     */
    event PresaleClosed();

    /**
     * Event for Opening Presale
     */
    event PresaleOpened();

    /**
     * @dev Emit when new token are set by owner
     * @param newToken the new token including
     */
    event SetToken(address newToken);

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param value weis paid for purchase
     */
    event TokenPurchase(address indexed purchaser, uint256 value);

    /**
     * Event for token withdrawal logging
     * @param beneficiary beneficiary who receives the withdrawn tokens
     * @param amount amount of tokens withdrawn
     */
    event TokenWithdrawn(address indexed beneficiary, uint256 amount);

    /**
     * @dev Emitted when the treasury wallet address is updated.
     * @param oldWallet The address of the previous treasury wallet.
     * @param newWallet The address of the new treasury wallet.
     * @notice This event provides a transparent record of changes to the treasury wallet.
     * It is emitted when the owner successfully updates the treasury wallet address
     * using the {setTreasuryWallet} function.
     */
    event TreasuryWalletUpdated(
        address indexed oldWallet,
        address indexed newWallet
    );

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     */
    function buyTokens() external payable;

    /**
     * @dev after presale,remaining tokens needed to be withdrawn
     * @param _to Address recipient
     * @param _amount uint256 amount of tokens sent to the recipient
     */
    function withdraw(address _to, uint256 _amount) external;

    /**
     * @dev Allows the owner to set a new treasury wallet address.
     * @param _newWallet The address of the new treasury wallet.
     * @notice Only the owner has the privilege to update the treasury wallet.
     * @dev Emits a {TreasuryWalletUpdated} event with the old and new wallet addresses.
     * @dev Reverts if the new wallet address is invalid (zero address).
     */
    function setTreasuryWallet(address _newWallet) external;

    /**
     * @notice Closes the presale, preventing any further purchases.
     * @dev This action is irreversible and can only be performed by the contract owner. It should set the presale state to closed.
     */
    function closePresale() external;

    /**
     * @dev Set the token address
     * @dev Only callable by owner
     * @param newToken address of the new ERC20 token
     */
    function setToken(address newToken) external;

    /**
     * @notice Opens the presale, permitting any further purchases.
     * @dev This action is irreversible and can only be performed by the contract owner. It should set the presale state to opened.
     */
    function openPresale() external;

    /**
     * @dev Calculates the total amount of tokens a buyer is eligible to claim based on their contribution.
     * @param _buyer The address of the buyer.
     * @return The total number of tokens the buyer is eligible to claim.
     */
    function getTokenBalance(address _buyer) external view returns (uint256);

    /**
     * @dev Calculates the total amount of Wei a buyer withdrawn based on their contribution.
     * @param _buyer The address of the buyer.
     * @return The total number of tokens the buyer is eligible to claim.
     */
    function getTotalTokensWithdrawn(
        address _buyer
    ) external view returns (uint256);

    /**
     * @dev Calculates the remaining amount of tokens a buyer can claim at the current time.
     * @param _buyer The address of the buyer.
     * @return The number of tokens the buyer can still claim.
     */
    function calculateEligibleTokens(
        address _buyer
    ) external view returns (uint256);

    /// @notice Enables buyers to withdraw their allocated tokens after the presale ends.
    /// @dev Should ensure that tokens are only withdrawn in accordance with presale rules.
    function withdrawTokens() external;
}
