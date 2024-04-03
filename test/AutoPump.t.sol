// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/console.sol";
import {Test, console2} from "forge-std/Test.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    UNISWAP_V2_ROUTER02,
    SUSHISWAP_V2_ROUTER02,
    PANCAKESWAP_V2_ROUTER02,
    DACKIE_V2_ROUTER02
} from "test/utils/constant_eth.sol";

import {AutoPump, IAutoPump} from "../src/AutoPump.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AutoPumpTest is Test {
    struct Fees {
        uint256 burnFee;
        uint256 pumpFee;
        uint256 liquifyFee;
    }

    uint256 mainnetFork;
    uint256 totalSupply = 1e12 ether;
    uint256 burnFee = 500;
    uint256 liqFee = 200;
    uint256 pumpFee = 300;
    IAutoPump.Fees fees = IAutoPump.Fees(burnFee, pumpFee, liqFee);
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    address owner;
    address buyer;
    address buyer2;
    address seller;
    address seller2;
    address uniswapV2Pair;
    address uniswapV2Pair2;

    AutoPump token;
    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Router02 public uniswapV2Router2;

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        owner = makeAddr("owner");
        buyer = makeAddr("buyer");
        buyer2 = makeAddr("buyer2");
        seller = makeAddr("seller");
        seller2 = makeAddr("seller2");
        vm.deal(owner, 200_000 ether);

        vm.prank(owner);
        token = new AutoPump("AutoPump", "AUTO", totalSupply, fees, UNISWAP_V2_ROUTER02, SUSHISWAP_V2_ROUTER02);
        uniswapV2Router = IUniswapV2Router02(UNISWAP_V2_ROUTER02);
        uniswapV2Pair = token.uniswapV2Pair();
        uniswapV2Router2 = IUniswapV2Router02(SUSHISWAP_V2_ROUTER02);
        uniswapV2Pair2 = token.uniswapV2Pair2();

        vm.startPrank(owner);
        token.setPumpThreshold(1 ether);
        token.setLiquifyThreshold(type(uint256).max);
        token.approve(UNISWAP_V2_ROUTER02, type(uint256).max);
        token.approve(SUSHISWAP_V2_ROUTER02, type(uint256).max);
        uniswapV2Router.addLiquidityETH{value: 300 ether }(address(token), totalSupply / 4, 0, 0, owner, block.timestamp);
        uniswapV2Router2.addLiquidityETH{value: 300 ether }(address(token), totalSupply / 4, 0, 0, owner, block.timestamp);
        vm.stopPrank();
    }

function testSetRouter() public {
        address oldPair = token.uniswapV2Pair();
        vm.prank(owner);
        token.setRouterAddress(SUSHISWAP_V2_ROUTER02);

        assert(address(token.uniswapV2Pair()) != oldPair);
        assert(address(token.uniswapV2Router()) != UNISWAP_V2_ROUTER02);
        assertEq(address(token.uniswapV2Router()), SUSHISWAP_V2_ROUTER02);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        vm.prank(buyer);
        token.setRouterAddress(UNISWAP_V2_ROUTER02);

        address oldPair2 = token.uniswapV2Pair2();
        vm.prank(owner);
        token.setRouterAddress2(UNISWAP_V2_ROUTER02);

        assert(address(token.uniswapV2Pair2()) != oldPair2);
        assert(address(token.uniswapV2Router2()) != SUSHISWAP_V2_ROUTER02);
        assertEq(address(token.uniswapV2Router2()), UNISWAP_V2_ROUTER02);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        vm.prank(buyer);
        token.setRouterAddress2(SUSHISWAP_V2_ROUTER02);
    }

    function testSetFees() public {
        IAutoPump.Fees memory fee = IAutoPump.Fees(200, 300, 400);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        vm.prank(buyer);
        token.setFees(fee);

        vm.prank(owner);
        token.setFees(fee);

        (uint256 _burnFee, uint256 _pumpFee, uint256 _liquifyFee) = token.fees();

        assertEq(_burnFee, 200);
        assertEq(_pumpFee, 300);
        assertEq(_liquifyFee, 400);
    }

    function testSetThreshold() public {
        vm.prank(owner);
        token.setPumpThreshold(2 ether);
        vm.prank(owner);
        token.setLiquifyThreshold(2 ether);

        assertEq(token.pumpEthThreshold(), 2 ether);
        assertEq(token.liquifyTokenThreshold(), 2 ether);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        vm.prank(buyer);
        token.setPumpThreshold(1 ether);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        vm.prank(buyer);
        token.setLiquifyThreshold(1 ether);
    }

    function testSetEnable() public {
        vm.prank(owner);
        token.setExcludeFromFee(owner, false);
        vm.prank(owner);
        token.setSwapAndLiquifyEnabled(false);
        vm.prank(owner);
        token.setPumpEnabled(false);

        assertEq(token._isExcludedFromFee(owner), false);
        assertEq(token.swapAndLiquifyEnabled(), false);
        assertEq(token.pumpEnabled(), false);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        vm.prank(buyer);
        token.setExcludeFromFee(buyer, true);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        vm.prank(buyer);
        token.setSwapAndLiquifyEnabled(true);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, buyer));
        vm.prank(buyer);
        token.setPumpEnabled(true);
    }

    function testBuy() public {
        vm.deal(buyer, 100 ether);
        uint256 ethBalBefore = buyer.balance;
        uint256 tokenBalBefore = token.balanceOf(buyer);
        swapEthForTokens(buyer, 1e16);
        uint256 ethBalAfter = buyer.balance;
        uint256 tokenBalAfter = token.balanceOf(buyer);

        assert(tokenBalAfter > tokenBalBefore);
        assertEq(ethBalBefore - ethBalAfter, 1e16);
        assertGt(address(token).balance, 0); //no pump eth for swap
    }

    function testBuyFuzz(uint256 amount, uint256 balance) public {
        amount = bound(amount, 1 ether, token.balanceOf(owner));
        vm.assume(balance > amount);
        
        vm.deal(buyer, balance);
        uint256 ethBalBefore = buyer.balance;
        uint256 tokenBalBefore = token.balanceOf(buyer);
        swapEthForTokens(buyer, amount);
        uint256 ethBalAfter = buyer.balance;
        uint256 tokenBalAfter = token.balanceOf(buyer);

        assert(tokenBalAfter > tokenBalBefore);
        assertEq(ethBalBefore - ethBalAfter, amount);
        assertGt(address(token).balance, 0); //no pump eth for swap
    }

    function testSell() public {
        vm.prank(owner);
        uint256 amountToSell = 4000e18;
        token.transfer(buyer, amountToSell);
        vm.prank(buyer);

        uint256 ethBalBefore = buyer.balance;
        uint256 buyerBalBefore = token.balanceOf(buyer);
        uint256 tokenBalBefore = token.balanceOf(address(token));
        uint256 totlaSupplyBefore = token.totalSupply();
        swapTokensForEth(buyer, amountToSell);
        uint256 ethBalAfter = buyer.balance;
        uint256 buyerBalAfter = token.balanceOf(buyer);
        uint256 tokenBalAfter = token.balanceOf(address(token));
        uint256 totlaSupplyAfter = token.totalSupply();

        uint256 expectedLiquifyFee = amountToSell * liqFee / 1e4;
        uint256 expectedBurnFee = amountToSell * burnFee / 1e4;

        assert(ethBalAfter > ethBalBefore);
        assertEq(buyerBalBefore - buyerBalAfter, amountToSell);
        assertEq(tokenBalAfter - tokenBalBefore, expectedLiquifyFee);
        assertEq(totlaSupplyBefore - totlaSupplyAfter, expectedBurnFee);
        assertGt(address(token).balance, 0); //no pump eth for swap
    }

    function testSellFuzz(uint256 amountToSell) public {
        amountToSell = bound(amountToSell, 1 ether, token.totalSupply()/4);
        vm.prank(owner);
        token.transfer(buyer, amountToSell);

        uint256 ethBalBefore = buyer.balance;
        uint256 buyerBalBefore = token.balanceOf(buyer);
        uint256 tokenBalBefore = token.balanceOf(address(token));
        uint256 totlaSupplyBefore = token.totalSupply();
        swapTokensForEth(buyer, amountToSell);
        uint256 ethBalAfter = buyer.balance;
        uint256 buyerBalAfter = token.balanceOf(buyer);
        uint256 tokenBalAfter = token.balanceOf(address(token));
        uint256 totlaSupplyAfter = token.totalSupply();

        uint256 expectedLiquifyFee = amountToSell * liqFee / 1e4;
        uint256 expectedBurnFee = amountToSell * burnFee / 1e4;

        assert(ethBalAfter > ethBalBefore);
        assertEq(buyerBalBefore - buyerBalAfter, amountToSell);
        assertEq(tokenBalAfter - tokenBalBefore, expectedLiquifyFee);
        assertEq(totlaSupplyBefore - totlaSupplyAfter, expectedBurnFee);
        assertGt(address(token).balance, 0); //no pump eth for swap
    }

    function testTransferFuzz(uint256 amount1, uint256 amount2, uint256 amount3, uint256 amount4) public {
        amount1 = bound(amount1, 1 ether, totalSupply / 100);
        amount2 = bound(amount2, 1 ether, totalSupply / 100);
        amount3 = bound(amount3, 1 ether, totalSupply / 100);
        amount4 = bound(amount4, 1 ether, totalSupply / 150);
        
        vm.startPrank(owner);
        token.transfer(buyer, amount1 + amount3);
        token.transfer(buyer2, amount2 + amount4);
        token.setPumpThreshold(type(uint256).max);

        vm.stopPrank();

        address pair = getPair();
        _testTransfer(pair, seller, buyer, amount1);
        skip(1);
        pair = getPair();
        _testTransfer(pair, seller, buyer2, amount2);
        skip(1);
        pair = getPair();
        _testTransfer(pair, seller2, buyer, amount3);
        skip(1);
        pair = getPair();
        _testTransfer(pair, seller2, buyer2, amount4);
    }

    function testLiquifyFuzz(uint256 threshold, uint256 amount) public {
        amount = bound(amount, 1 ether, token.totalSupply() / 14);
        threshold = bound(threshold, amount, token.totalSupply() / 14);

        vm.prank(owner);
        token.transfer(buyer, amount);

        address pair = getPair();
        console.log(block.timestamp % 2);
        _testLiquify(pair, threshold, amount);
        skip(1);
        pair = getPair();
        console.log(block.timestamp % 2);
        _testLiquify(pair, threshold, amount);
    }

    function testPumpFuzz(uint256 amount) public {
        amount = bound(amount, 1 ether, token.totalSupply() / 14);

        vm.startPrank(owner);
        token.transfer(buyer, amount);
        vm.deal(address(token), 22e17);
        vm.stopPrank();

        address pair = getPair();
        console.log(block.timestamp % 2);
        _testPump(pair, amount);
        skip(1);
        pair = getPair();
        console.log(block.timestamp % 2);
        _testPump(pair, amount);
    }

    function swapEthForTokens(address account, uint256 ethAmount) private {
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(token);
        vm.prank(account);
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethAmount}(
            0, path, account, block.timestamp
        );
    }

    function swapTokensForEth(address account, uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = uniswapV2Router.WETH();
        vm.prank(account);
        token.approve(UNISWAP_V2_ROUTER02, tokenAmount);
        vm.prank(account);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            account,
            block.timestamp
        );
    }

    function _testPump(address pair, uint256 amount) private {

        uint256 beforePumpBal = address(token).balance;
        uint256 beforePumpBal2 = IERC20(address(uniswapV2Router.WETH())).balanceOf(pair);
        uint256 beforePumpBal3 = token.balanceOf(pair);
        uint256 beforeTotalSupply = token.totalSupply();
        vm.prank(buyer);
        token.transfer(owner, amount / 2);
        uint256 afterPumpBal = address(token).balance;
        uint256 afterPumpBal2 = IERC20(address(uniswapV2Router.WETH())).balanceOf(pair);
        uint256 afterPumpBal3 = token.balanceOf(pair);
        uint256 afterTotalSupply = token.totalSupply();

        assert(beforePumpBal > afterPumpBal);
        assert(afterPumpBal2 > beforePumpBal2);
        assertApproxEqRel(beforeTotalSupply - afterTotalSupply, beforePumpBal3 - afterPumpBal3, 0.1e15);
    }

    function _testTransfer(address pair, address receiver, address sender, uint256 amount) private {
        uint256 ethBalBefore = address(token).balance;
        uint256 senderBalBefore = token.balanceOf(sender);
        uint256 totalSupplyBefore = token.totalSupply();
        uint256 tokenBalBefore = token.balanceOf(address(token));
        uint256 pairTokenBefore = token.balanceOf(pair);
        uint256 receiverBalBefore = token.balanceOf(receiver);

        vm.prank(sender);
        token.transfer(receiver, amount);

        uint256 tokenBefore = tokenBalBefore;
        uint256 pairTokenAfter = token.balanceOf(pair);
        uint256 senderBalAfter = token.balanceOf(sender);
        uint256 receiverBalAfter = token.balanceOf(receiver);

        uint256 amountToTransfer = amount;

        assertEq(senderBalBefore - senderBalAfter, amountToTransfer);
        
        assert(address(token).balance > ethBalBefore);

        uint256 expectedBurnFee = amountToTransfer * burnFee / 1e4;

        assertEq(totalSupplyBefore - token.totalSupply(), expectedBurnFee);

        uint256 expectedLiquifyFee = amountToTransfer * liqFee / 1e4;
        uint256 expectedPumpFee = amountToTransfer * pumpFee / 1e4;
        uint256 totalFee = expectedPumpFee + expectedBurnFee + expectedLiquifyFee;

        assertEq(receiverBalAfter - receiverBalBefore, amountToTransfer - totalFee);

        assertEq(token.balanceOf(address(token)) - tokenBefore, expectedLiquifyFee);

        assertEq(pairTokenAfter - pairTokenBefore, expectedPumpFee);
    }

    function _testLiquify(address pair, uint256 threshold, uint256 amount) private {
        vm.startPrank(owner);
        token.transfer(address(token), threshold + 1);
        token.setLiquifyThreshold(threshold);
        vm.stopPrank();

        uint256 beforeLiquifyBal = token.balanceOf(address(token));
        uint256 beforeLiquifyBal2 = token.balanceOf(pair);
        vm.prank(buyer);
        token.transfer(seller, amount / 2);
        uint256 afterLiquifyBal = token.balanceOf(address(token));
        uint256 afterLiquifyBal2 = token.balanceOf(pair);
    
        assert(beforeLiquifyBal > afterLiquifyBal);

        assert(afterLiquifyBal2 > beforeLiquifyBal2);

        vm.prank(owner);
        token.setLiquifyThreshold(type(uint256).max);
    }

    function getPair() private view returns(address) {
        return block.timestamp % 2 == 0 ? token.uniswapV2Pair() : token.uniswapV2Pair2();
    }
}