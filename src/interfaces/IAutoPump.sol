// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAutoPump is IERC20 {
    struct Fees {
        uint256 burnFee;
        uint256 pumpFee;
        uint256 liquifyFee;
    }

    /**
     * @dev Emit when liquify threshold reach and add liquidity to token pair
     * @param tokensSwapped half of the threshold amount that provided as AutoPump token
     * @param ethReceived amount of ETH received for half of tokens and added as liquidity
     */
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived);

    /**
     * @dev Emit when pump threshold reach and burn the bought tokens
     * @param ethSwapped amount of eth that swapped and burnt
     */
    event SwapAndPump(uint256 ethSwapped);

    /**
     * @dev Emit when router address is updated
     * @param oldRouter old router address
     * @param newRouter new router address
     */
    event RouterAddressUpdated(address oldRouter, address newRouter);

    /**
     * @dev Emit when swap and liquify status updated
     * @param oldStatus prev status of mechanism
     * @param newStatus new status of mechanism
     */
    event SwapAndLiquifyUpdated(bool oldStatus, bool newStatus);

    /**
     * @dev Emit when pump mechanism status updated
     * @param oldStatus prev status of mechanism
     * @param newStatus new status of mechanism
     */
    event PumpUpdated(bool oldStatus, bool newStatus);

    /**
     * @dev Emit when pump threshold is updated
     * @param oldThreshold prev threshold for pump
     * @param newThreshold new threshold for pump
     */
    event PumpThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    /**
     * @dev Emit when liquify threshold is updated
     * @param oldThreshold prev threshold for liquifying
     * @param newThreshold new threshold for liquifying
     */
    event LiquifyThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    /**
     * @dev Emit when an address status changes for excluding from fees
     * @param account updated address
     * @param status for excluding from fees
     */
    event ExcludeFromFeeUpdated(address account, bool status);

    /**
     * @dev Emit when new fees are set by owner
     * @param oldfees the old fees including burn, pump and liquify fees
     * @param newFees the new fees including burn, pump and liquify fees
     */
    event FeesUpdated(Fees oldfees, Fees newFees);

    /**
     * @dev Set the first DEX router address and creates the new token pair
     * @dev Only callable by owner
     * @param newRouter address of the new router
     */
    function setRouterAddress(address newRouter) external;

    /**
     * @dev Set the second DEX router address and creates the new token pair
     * @dev Only callable by owner
     * @param newRouter address of the new router
     */
    function setRouterAddress2(address newRouter) external;

    /**
     * @dev Set the pump threshold for ETH that swaps and burns the tokens
     * @dev Only callable by owner
     * @param amountToUpdate new amount of threshold for ETH
     */
    function setPumpThreshold(uint256 amountToUpdate) external;

    /**
     * @dev Set the liquify threshold for AutoPump token that provides liquidity to token pair
     * @dev Only callable by owner
     * @param amountToUpdate new amount of threshold for AutoPump token
     */
    function setLiquifyThreshold(uint256 amountToUpdate) external;

    /**
     * @dev Set the address status for excluding from the fees
     * @dev Only callable by owner
     * @param account address of the account to change the excluding status
     * @param status boolean status of excluding from the fees
     */
    function setExcludeFromFee(address account, bool status) external;

    /**
     * @dev Set the status for enabling liquifying tokens
     * @dev Only callable by owner
     * @param enabled boolean status of Liquify
     */
    function setSwapAndLiquifyEnabled(bool enabled) external;

    /**
     * @dev Set the status for enabling pump
     * @dev Only callable by owner
     * @param enabled boolean status of Pump mechanism
     */
    function setPumpEnabled(bool enabled) external;

    /**
     * @dev Set new fees
     * @dev Only callable by owner
     * @param _fees struct of fees including burn, pump and liquify fee percentages
     */
    function setFees(Fees memory _fees) external;
}
