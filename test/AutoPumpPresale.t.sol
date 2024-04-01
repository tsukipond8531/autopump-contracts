// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/console.sol";
import { Test, console2 } from "forge-std/Test.sol";
import { IAutoPumpPresale } from "../src/interfaces/IAutoPumpPresale.sol";
import { AutoPumpPresale } from "../src/AutoPumpPresale.sol";
import { AutoPump, IAutoPump } from "../src/AutoPump.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { UNISWAP_V2_ROUTER02, SUSHISWAP_V2_ROUTER02, PANCAKESWAP_V2_ROUTER02, FRAXSWAP_V2_ROUTER02 } from "test/utils/constant_eth.sol";

contract AutoPumpPresaleTest is Test {
    AutoPumpPresale public autoPumpPresale;
    AutoPump public autoPumpToken;

    address treasuryWallet = address(0x123);
    uint256 fundraisingGoal = 100 ether;

    // actuale rate will be rate and the precision is to gain to decimals
    uint256 rate = 400_00; // (400_00 / 100) = 400 as we have 100 precision

    address[10] public users;

    address owner;
    address buyer1;

    function setUp() public {
        owner = address(this);
        buyer1 = makeAddr("buyer1");

        // Assuming MAINNET_RPC_URL is set in your environment variables
        // for the test setup to use mainnet forking
        string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(rpcUrl);
        vm.selectFork(forkId);

        autoPumpToken = new AutoPump(
            "AutoPump",
            "AUTO",
            1_000_000_000_000 ether, // Initial supply
            IAutoPump.Fees({ burnFee: 2, pumpFee: 3, liquifyFee: 4 }),
            UNISWAP_V2_ROUTER02,
            SUSHISWAP_V2_ROUTER02 // Assuming this constructor takes two routers
        );

        autoPumpPresale = new AutoPumpPresale(treasuryWallet, ERC20(address(autoPumpToken)), fundraisingGoal, rate);

        // Initialize user addresses.
        // Use vm.addr to generate addresses with ETH for testing
        for (uint256 i = 0; i < users.length; i++) {
            users[i] = vm.addr(i + 1); // Generate addresses that have ETH
        }

        // Exclude the presale contract from fees
        autoPumpToken.setExcludeFromFee(address(autoPumpPresale), true);

        // Here, simply transferring a portion of the initial supply for simplicity.
        autoPumpToken.transfer(address(autoPumpPresale), autoPumpToken.totalSupply() / 2);

        autoPumpPresale.openPresale();
    }

    function testInitialization() public view {
        assertEq(autoPumpPresale.treasuryWallet(), treasuryWallet);
        assertEq(autoPumpPresale.fundraisingGoal(), fundraisingGoal);
        assertTrue(address(autoPumpPresale.token()) == address(autoPumpToken));
        assertEq(autoPumpPresale.rate(), rate);
    }

    function testRevertSetToken() public {
        vm.prank(buyer1);
        vm.expectRevert();
        autoPumpPresale.setToken(address(1));

        vm.expectRevert("Invalid Token Address");
        autoPumpPresale.setToken(address(0));
    }

    function testRevertOpenPresale() public {
        vm.expectRevert("Presale already opened");
        autoPumpPresale.openPresale();
    }

    function testBuyTokens() public {
        uint256 purchaseAmount = 10 ether;
        (bool success, ) = payable(address(autoPumpPresale)).call{ value: purchaseAmount }("");
        assertTrue(success);

        uint256 targetedPresaleTokenBalance = (purchaseAmount * rate) / autoPumpPresale.PRECISION_MULTIPLIER();

        uint256 presaleTokenBalance = autoPumpPresale.getTokenBalance(address(this));

        assertEq(autoPumpPresale.raisedAmount(), purchaseAmount);
        assertEq(presaleTokenBalance, targetedPresaleTokenBalance);
    }

    function testRevertInvestorBuyTokens() public {
        uint256 purchaseAmount = 1001 ether;
        bool success;
        NonReceivable nonReceivable = new NonReceivable();

        vm.deal(address(nonReceivable), purchaseAmount);
        vm.prank(address(nonReceivable));
        vm.expectRevert("Refund failed");
        (success, ) = payable(address(autoPumpPresale)).call{ value: purchaseAmount }("");

        assertTrue(success);
    }

    function testRevertTreasuryWalletReceivingFunds() public {
        uint256 purchaseAmount = 10 ether;
        bool success;
        NonReceivable nonReceivable = new NonReceivable();

        autoPumpPresale.setTreasuryWallet(address(nonReceivable));
        vm.expectRevert("Failed to send Accepted Wei");
        (success, ) = payable(address(autoPumpPresale)).call{ value: purchaseAmount }("");
        assertTrue(success);
    }

    function testClosePresale() public {
        // Assuming ether contributions have been made to the presale
        uint256 contributionAmount = 1 ether;
        (bool success, ) = payable(address(autoPumpPresale)).call{ value: contributionAmount }("");
        assertTrue(success);

        // Check if contributions are recorded correctly
        assertEq(autoPumpPresale.raisedAmount(), contributionAmount);

        // Close the presale
        autoPumpPresale.closePresale();

        // Verify that the presale is marked as closed
        assertTrue(autoPumpPresale.presaleClosed());
    }

    function testSetTreasuryWallet() public {
        autoPumpPresale.setTreasuryWallet(owner);

        // Verify that the treasury wallet is marked for the owner
        assertEq(autoPumpPresale.treasuryWallet(), owner);
    }

    function testSetToken() public {
        autoPumpPresale.setToken(address(1));

        // Verify that the token is marked for the owner
        assertEq(address(autoPumpPresale.token()), address(1));
    }

    function testWithdraw() public {
        autoPumpPresale.withdraw(address(this), autoPumpToken.balanceOf(address(autoPumpPresale)));

        // Verify that the treasury wallet is marked for the owner
        assertEq(autoPumpToken.balanceOf(address(autoPumpPresale)), 0);
    }

    function testRevertSetTreasuryWallet() public {
        vm.expectRevert("Invalid Wallet Address");
        autoPumpPresale.setTreasuryWallet(address(0));
    }

    function testGetTokenBalance() public {
        // Example setup: A buyer contributes 1 ETH.
        uint256 contribution = 1 ether;
        vm.deal(address(this), contribution);
        autoPumpPresale.buyTokens{ value: contribution }();

        // Close the presale to proceed with eligibility calculations.
        autoPumpPresale.closePresale();

        // Assuming a direct 1 ETH: 100 tokens for simplicity.
        uint256 expectedEligibleTokens = (contribution * rate) / autoPumpPresale.PRECISION_MULTIPLIER(); // Adjust according to your distribution rules.
        // console2.log("expectedEligibleTokens", expectedEligibleTokens);

        uint256 actualEligibleTokens = autoPumpPresale.getTokenBalance(address(this));
        assertEq(actualEligibleTokens, expectedEligibleTokens, "Total eligible tokens should match contribution");
    }

    function testContributionExceedsFundraisingGoal() public {
        uint256 excessContribution = 200 ether;

        // Simulate sending ETH to buy tokens, exceeding the fundraising goal
        vm.deal(address(this), excessContribution);
        autoPumpPresale.buyTokens{ value: excessContribution }();

        // Check if the weiRaised in the presale contract matches the fundraising goal exactly
        assertEq(autoPumpPresale.raisedAmount(), fundraisingGoal);
    }

    function testBuyTokensAfterPresaleEnds() public {
        // Close the presale to prevent further contributions
        autoPumpPresale.closePresale();

        // Verify presale is closed
        assertTrue(autoPumpPresale.presaleClosed(), "Presale should be closed");

        // Try to buy tokens after presale has ended
        uint256 contributionAfterClose = 1 ether;
        vm.deal(address(this), contributionAfterClose);

        // Expectation: The transaction should revert because the presale is closed
        vm.expectRevert("Presale is closed");
        autoPumpPresale.buyTokens{ value: contributionAfterClose }();

        // Optionally, verify no change in weiRaised and contributor's balance to ensure no contribution was accepted
        assertEq(autoPumpPresale.raisedAmount(), 0, "No funds should be raised after presale ends");
        assertEq(
            address(this).balance,
            contributionAfterClose,
            "Contributor should retain their funds after failed contribution"
        );
    }

    function testRevertClosePresale() public {
        autoPumpPresale.closePresale();

        vm.expectRevert("Presale already closed");
        autoPumpPresale.closePresale();
    }

    function testWithdrawTokensBeforePassingLockupPeriod() public {
        // Buyer contributes some amount (e.g., 1 ETH).
        uint256 contribution = 1 ether;
        vm.deal(address(this), contribution);
        autoPumpPresale.buyTokens{ value: contribution }();

        // Presale is closed to proceed to the withdrawal phase.
        autoPumpPresale.closePresale();

        // Fast-forward time beyond the presale end but the lock up period didn't end yet.
        vm.warp(block.timestamp + 4 days);

        // The buyer try to withdraw his eligible tokens.
        vm.expectRevert("Lockup period not ended");
        autoPumpPresale.withdrawTokens();

        // Expected eligible tokens to be zero because lock up period didn't end yet.
        uint256 expectedEligibleTokens = 0;

        // Get the actual remaining tokens that can be claimed.
        uint256 actualRemainingTokens = autoPumpPresale.calculateEligibleTokens(address(this));

        // Verify the remaining tokens match the expected amount.
        assertEq(
            actualRemainingTokens,
            expectedEligibleTokens,
            "Buyer should have no remaining tokens to claim after withdrawal."
        );
    }

    function testRevertWithdrawTokensOnOpenedPresale() public {
        // Buyer contributes some amount (e.g., 1 ETH).
        uint256 contribution = 1 ether;
        vm.deal(address(this), contribution);
        autoPumpPresale.buyTokens{ value: contribution }();

        // Fast-forward time beyond the presale end but the lock up period didn't end yet.
        vm.warp(block.timestamp + 4 days);

        // The buyer try to withdraw his eligible tokens.
        vm.expectRevert("Presale not closed yet");
        autoPumpPresale.withdrawTokens();

        // Expected eligible tokens to be zero because lock up period didn't end yet.
        uint256 expectedEligibleTokens = 0;

        // Get the actual remaining tokens that can be claimed.
        uint256 actualRemainingTokens = autoPumpPresale.calculateEligibleTokens(address(this));

        // Verify the remaining tokens match the expected amount.
        assertEq(
            actualRemainingTokens,
            expectedEligibleTokens,
            "Buyer should have no remaining tokens to claim after withdrawal."
        );
    }

    function testWithdrawTokensAndCheckRemaining() public {
        // Buyer contributes some amount (e.g., 1 ETH).
        uint256 contribution = 1 ether;
        vm.deal(buyer1, contribution);
        vm.prank(buyer1);
        autoPumpPresale.buyTokens{ value: contribution }();

        // Presale is closed to proceed to the withdrawal phase.
        vm.prank(address(this));
        autoPumpPresale.closePresale();

        // Fast-forward time beyond the presale end to when withdrawals are allowed.
        vm.warp(block.timestamp + 8 days);

        // The buyer withdraws their eligible tokens.
        vm.prank(buyer1);
        autoPumpPresale.withdrawTokens();

        // Get the actual remaining tokens that can be claimed.
        uint256 actualRemainingTokens = autoPumpPresale.calculateEligibleTokens(buyer1);
        uint256 buyerTotalWithdrawn = autoPumpPresale.getTotalTokensWithdrawn(buyer1);

        // Verify the remaining tokens match the expected amount.
        assertEq(
            actualRemainingTokens,
            0,
            "Buyer should have no remaining tokens to claim after withdrawal at that period of time."
        );
        assertEq(
            buyerTotalWithdrawn,
            autoPumpToken.balanceOf(buyer1),
            "Buyer should have withrawn a batch of his tokens."
        );
    }

    function testGradualWithdrawal() public {
        // Buyer contributes 1 ETH.
        uint256 contribution = 1 ether;
        vm.deal(buyer1, contribution);
        vm.prank(buyer1);
        autoPumpPresale.buyTokens{ value: contribution }();

        // Close the presale.
        vm.prank(address(this));
        autoPumpPresale.closePresale();

        vm.startPrank(buyer1);
        // Simulate several withdrawal attempts at different times.
        for (uint256 i = 1; i <= 12; i++) {
            // Fast-forward time by increments to simulate gradual withdrawal eligibility.
            vm.warp(block.timestamp + 6 days * i); // Example: every 14 days.

            // Check if there are eligible tokens for withdrawal before attempting.
            uint256 remainingAmountClaimableBeforeWithdrawal = autoPumpPresale.calculateEligibleTokens(buyer1);
            uint256 balanceBeforeWithdrawal = autoPumpToken.balanceOf(buyer1);

            if (remainingAmountClaimableBeforeWithdrawal > 0) {
                // Attempt withdrawal only if eligible tokens are > 0.
                if (block.timestamp < autoPumpPresale.closedPresaleTime() + autoPumpPresale.LOCKUP_PERIOD_DAYS()) {
                    vm.expectRevert("Lockup period not ended");
                    autoPumpPresale.withdrawTokens();
                } else {
                    autoPumpPresale.withdrawTokens();
                }

                uint256 balanceAfterWithdrawal = autoPumpToken.balanceOf(buyer1);

                assertEq(
                    balanceBeforeWithdrawal + remainingAmountClaimableBeforeWithdrawal,
                    balanceAfterWithdrawal,
                    "Mismatch in remaining tokens after withdrawal."
                );
            }
        }

        uint256 balanceAfterPresale = autoPumpToken.balanceOf(buyer1);
        uint256 totalTokensWithdrawn = autoPumpPresale.getTotalTokensWithdrawn(buyer1);

        assertEq(balanceAfterPresale, totalTokensWithdrawn, "Mismatch in total withdrawn tokens after presale.");
        assertEq(
            balanceAfterPresale,
            (contribution * rate) / autoPumpPresale.PRECISION_MULTIPLIER(),
            "Mismatch in contribution and total withdrawn tokens after presale."
        );
        vm.stopPrank();
    }

    function testBuyAndWithdrawTokensAfterWithdrawalPeriod() public {
        // Step 1: Simulate a buyer purchasing tokens before presale ends
        uint256 purchaseAmount = 10 ether;
        vm.deal(buyer1, purchaseAmount);
        vm.startPrank(buyer1);
        autoPumpPresale.buyTokens{ value: purchaseAmount }();
        vm.stopPrank();

        // Ensure the contribution is recorded
        assertEq(autoPumpPresale.raisedAmount(), purchaseAmount, "Contribution should be recorded");

        // Step 2: Close the presale to end token purchases
        vm.prank(address(this));
        autoPumpPresale.closePresale();
        assertTrue(autoPumpPresale.presaleClosed(), "Presale should be marked as closed");

        // Step 3: Fast-forward time beyond the withdrawal period
        vm.warp(block.timestamp + autoPumpPresale.WITHDRAWAL_PERIOD_DAYS() + 69 days);

        // Step 4: Attempt to withdraw allocated tokens after the presale ends
        vm.startPrank(buyer1);
        autoPumpPresale.withdrawTokens();
        vm.stopPrank();

        // Verify that the tokens have been successfully withdrawn
        uint256 finalTokenBalance = autoPumpToken.balanceOf(buyer1);
        uint256 totalTokensWithdrawn = autoPumpPresale.getTotalTokensWithdrawn(buyer1);

        assertEq(
            finalTokenBalance,
            (purchaseAmount * rate) / autoPumpPresale.PRECISION_MULTIPLIER(),
            "Tokens should be withdrawn successfully"
        );
        assertEq(
            finalTokenBalance,
            totalTokensWithdrawn,
            "Mismatch token balance with total tokens withdrawn should be withdrawn successfully"
        );
        vm.stopPrank();
    }

    // Fuzz Test: Buy Tokens with Randomized Amounts
    function testBuyTokensFuzz(uint256 _purchaseAmount) public {
        // Assume reasonable ETH contribution amount to avoid out-of-gas errors
        vm.assume(_purchaseAmount < address(this).balance);

        bool success;
        if (_purchaseAmount < 0.5 ether) {
            vm.expectRevert("Minimum buy amount 0.5 ETH");
            (success, ) = payable(address(autoPumpPresale)).call{ value: _purchaseAmount }("");

            assertEq(autoPumpPresale.raisedAmount(), 0);
        } else {
            (success, ) = payable(address(autoPumpPresale)).call{ value: _purchaseAmount }("");
            if (_purchaseAmount > fundraisingGoal) {
                assertTrue(autoPumpPresale.raisedAmount() == fundraisingGoal);
            } else {
                assertTrue(autoPumpPresale.raisedAmount() == _purchaseAmount);
            }
            assertTrue(success);
        }
    }

    // Fuzz Test: Contribute After Presale Ends with Randomized Amounts
    function testBuyTokensAfterPresaleEndsFuzz(uint256 _contributionAfterClose) public {
        autoPumpPresale.closePresale();

        vm.assume(_contributionAfterClose >= 0.5 ether && _contributionAfterClose < address(this).balance);

        vm.expectRevert("Presale is closed");
        autoPumpPresale.buyTokens{ value: _contributionAfterClose }();
    }

    // Fuzz Test: Purchase and Withdraw Tokens with Randomized Purchase Amount
    function testBuyAndWithdrawTokensAfterPresaleFuzz(uint256 _purchaseAmount) public {
        // Assume a valid purchase amount to avoid unrealistic scenarios
        vm.assume(_purchaseAmount >= 0.5 ether && _purchaseAmount <= fundraisingGoal);

        vm.deal(buyer1, _purchaseAmount);

        vm.prank(buyer1);
        autoPumpPresale.buyTokens{ value: _purchaseAmount }();

        // Check if the purchase was successful
        assertEq(
            autoPumpPresale.raisedAmount(),
            _purchaseAmount,
            "Contribution should be equal to the purchase amount"
        );

        // Close the presale
        // autoPumpPresale may close if the _purchaseAmount = fundraise goal amount
        if (autoPumpPresale.presaleClosed() == false) {
            vm.prank(address(this));
            autoPumpPresale.closePresale();
        }
        assertTrue(autoPumpPresale.presaleClosed(), "Presale should be marked as closed");

        // Warp time to after the withdrawal period
        vm.warp(block.timestamp + autoPumpPresale.LOCKUP_PERIOD_DAYS() + 2 days);

        uint256 eligibleTokensBeforeWithdraw = autoPumpPresale.calculateEligibleTokens(buyer1);

        if (autoPumpPresale.calculateEligibleTokens(buyer1) > 0) {
            vm.prank(buyer1);
            autoPumpPresale.withdrawTokens();
        } else {
            vm.prank(buyer1);
            vm.expectRevert("No tokens available for withdraw");
            autoPumpPresale.withdrawTokens();
        }

        assertNotEq(
            eligibleTokensBeforeWithdraw,
            (_purchaseAmount * rate) / autoPumpPresale.PRECISION_MULTIPLIER(),
            "Withdrawn tokens should not match the full expected allocation because we didn't pass whole withdraw period"
        );
    }

    function testGradualWithdrawalAfterPresaleFuzz(uint256 _purchaseAmount, uint256 _daysAfterPresaleClose) public {
        // Setup: Assume a valid purchase amount within the fundraising goal
        // Ensure the days after presale close is within a sensible range, for example, up to 2 years (~730 days)
        vm.assume(_purchaseAmount >= 0.5 ether && _daysAfterPresaleClose <= 730);

        // Simulate making a purchase
        vm.deal(buyer1, _purchaseAmount);
        vm.prank(buyer1);
        autoPumpPresale.buyTokens{ value: _purchaseAmount }();

        // Close the presale
        // autoPumpPresale may close if the _purchaseAmount = fundraise goal amount
        if (autoPumpPresale.presaleClosed() == false) {
            autoPumpPresale.closePresale();
        }

        // Warp time to simulate the days after presale closure for a withdrawal attempt
        vm.warp(block.timestamp + _daysAfterPresaleClose * 1 days);

        // Assuming your contract has a method to calculate eligible withdrawal amount based on time elapsed
        uint256 eligibleTokens = autoPumpPresale.calculateEligibleTokens(buyer1);

        // Simulate withdrawal
        // This requires the actual 'withdrawTokens' method in your contract to support partial withdrawals
        if (block.timestamp < autoPumpPresale.closedPresaleTime() + autoPumpPresale.LOCKUP_PERIOD_DAYS()) {
            vm.prank(buyer1);
            vm.expectRevert("Lockup period not ended");
            autoPumpPresale.withdrawTokens();

            // Verify the tokens withdrawn match the expected eligible amount at this point in time
            uint256 actualTokensWithdrawn = autoPumpToken.balanceOf(buyer1);

            // The expectedTokens should match the calculated eligible tokens allowed to be withdrawn at this time
            assertEq(actualTokensWithdrawn, 0, "Withdrawn tokens should match eligible amount");
        } else if (eligibleTokens == 0) {
            vm.prank(buyer1);
            vm.expectRevert("No tokens available for withdraw");
            autoPumpPresale.withdrawTokens();

            // Verify the tokens withdrawn match the expected eligible amount at this point in time
            uint256 actualTokensWithdrawn = autoPumpToken.balanceOf(buyer1);

            // The expectedTokens should match the calculated eligible tokens allowed to be withdrawn at this time
            assertEq(actualTokensWithdrawn, 0, "Withdrawn tokens should match eligible amount");
        } else if (eligibleTokens > 0) {
            vm.prank(buyer1);
            autoPumpPresale.withdrawTokens();

            // Verify the tokens withdrawn match the expected eligible amount at this point in time
            uint256 actualTokensWithdrawn = autoPumpToken.balanceOf(buyer1);

            // The expectedTokens should match the calculated eligible tokens allowed to be withdrawn at this time
            assertEq(actualTokensWithdrawn, eligibleTokens, "Withdrawn tokens should match eligible amount");
        }
    }

    function testMultiUserContributionFuzz(uint256[10] calldata _contributionAmounts) public {
        uint256 totalContributed = 0;

        // Simulate contributions from multiple users.
        for (uint256 i = 0; i < users.length; i++) {
            // Ensure contribution is within reasonable bounds.
            vm.assume(_contributionAmounts[i] <= 100 ether);

            // Assign ether to each user address to simulate contributions.
            vm.deal(users[i], _contributionAmounts[i]);

            // Simulate user contributing to the presale.
            if (_contributionAmounts[i] >= 0.5 ether) {
                vm.prank(users[i]);
                autoPumpPresale.buyTokens{ value: _contributionAmounts[i] }();
            } else {
                vm.prank(users[i]);
                vm.expectRevert("Minimum buy amount 0.5 ETH");
                autoPumpPresale.buyTokens{ value: _contributionAmounts[i] }();
            }

            // Accumulate total contributions to ensure it doesn't exceed the fundraising goal.
            totalContributed += _contributionAmounts[i];
            if (totalContributed >= fundraisingGoal) {
                break;
            }
        }

        // Close the presale after all contributions.
        // autoPumpPresale may close if the _purchaseAmount = fundraise goal amount
        if (autoPumpPresale.presaleClosed() == false) {
            autoPumpPresale.closePresale();
        }

        // Fast-forward time to allow for withdrawals.
        vm.warp(block.timestamp + autoPumpPresale.LOCKUP_PERIOD_DAYS() + autoPumpPresale.WITHDRAWAL_PERIOD_DAYS());

        // Verify each user's withdrawal amount.
        for (uint256 i = 0; i < users.length; i++) {
            uint256 eligibleTokens = autoPumpPresale.calculateEligibleTokens(users[i]);

            // Simulate withdrawal for users with eligible tokens.
            if (eligibleTokens > 0) {
                vm.prank(users[i]);
                autoPumpPresale.withdrawTokens();
            }
            uint256 actualWithdrawn = autoPumpToken.balanceOf(users[i]);
            assertEq(actualWithdrawn, eligibleTokens, "Mismatch in withdrawn tokens for user");
        }
    }

    // function testMultiUserContributionAndEarlyWithdrawalFuzz(uint256[10] calldata _contributionAmounts, uint256[10] calldata _daysAfterPresale) public {
    //     // Set up contributions and close the presale under the owner's authorization
    //     for (uint256 i = 0; i < users.length; i++) {

    //         if(autoPumpPresale.presaleClosed() == true) {
    //             break;
    //         }

    //         // Assumptions to keep contributions within sensible bounds
    //         vm.assume(_contributionAmounts[i] > 0 && _contributionAmounts[i] <= 100 ether);
    //         vm.deal(users[i], _contributionAmounts[i]);

    //         // Contributions are made by the users
    //         vm.startPrank(users[i]);
    //         autoPumpPresale.buyTokens{value: _contributionAmounts[i]}();
    //         vm.stopPrank();
    //     }

    //     // Close the presale after all contributions.
    //     // autoPumpPresale may close if the _purchaseAmount = fundraise goal amount
    //     if(autoPumpPresale.presaleClosed() == false) {
    //        vm.startPrank(address(this)); // Start acting as the owner
    //        autoPumpPresale.closePresale();
    //        vm.stopPrank(); // Stop acting as the owner
    //     }

    //     for (uint256 i = 0; i < users.length; i++) {
    //         // Ensure the days after presale close is within a reasonable range, up to 69 days to test early withdrawal
    //         vm.assume(_daysAfterPresale[i] > 0 && _daysAfterPresale[i] < 69);

    //         // Fast-forward time by the specified number of days for each user's withdrawal attempt
    //         vm.warp(block.timestamp + _daysAfterPresale[i] * 1 days);

    //         // Capture eligible tokens and total withdrawn before the attempt for later comparison
    //         uint256 eligibleTokensBeforeAttempt = autoPumpPresale.calculateEligibleTokens(users[i]);
    //         uint256 totalWithdrawnBeforeAttempt = autoPumpPresale.getBuyerTotalWithdrawn(users[i]);

    //         // Users attempt to withdraw tokens. Since it's before 69 days, expected behavior is based on your contract's rules.
    //         if(eligibleTokensBeforeAttempt > totalWithdrawnBeforeAttempt) {
    //             vm.startPrank(users[i]);
    //             autoPumpPresale.withdrawTokens();
    //             vm.stopPrank();
    //         }

    //         // Capture new eligible and withdrawn amounts
    //         uint256 totalWithdrawnAfterAttempt = autoPumpPresale.getBuyerTotalWithdrawn(users[i]);

    //         // Check if withdrawal was allowed or not and validate accordingly
    //         if (_daysAfterPresale[i] < 69) {
    //             // If withdrawal happens before 69 days,
    //             // you might expect no change, or partial withdrawals allowed based on elapsed time.
    //             assertTrue(totalWithdrawnAfterAttempt >= totalWithdrawnBeforeAttempt, "Withdrawal should be allowed or partial");
    //         } else {
    //             // If withdrawal happens after 69 days, ensure all eligible tokens can be withdrawn.
    //             uint256 actualWithdrawn = totalWithdrawnAfterAttempt - totalWithdrawnBeforeAttempt;
    //             assertEq(actualWithdrawn, eligibleTokensBeforeAttempt, "Should withdraw all eligible tokens after 69 days");
    //         }
    //     }
    // }

    receive() external payable {}
}

contract NonReceivable {
    receive() external payable {
        revert();
    }
}
