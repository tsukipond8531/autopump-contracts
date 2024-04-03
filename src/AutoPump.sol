// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "src/interfaces/IUniswapV2Factory.sol";
import {IAutoPump} from "src/interfaces/IAutoPump.sol";

/**
 * @notice AutoPump Implementation with Auto pump mechanism
 */
contract AutoPump is ERC20, Ownable, IAutoPump {
    mapping(address => bool) public _isExcludedFromFee;

    /// @dev fees percentage with 2 decimals
    Fees public fees;

    /**
     * @dev Threshold to Pump and Liquify the pair token
     */
    uint256 public pumpEthThreshold;
    uint256 public liquifyTokenThreshold;

    address public constant BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Router02 public uniswapV2Router2;
    address public uniswapV2Pair;
    address public uniswapV2Pair2;
    /// @dev Indicator to determine whether the status is currently in the liquifying
    bool public inSwapAndLiquify;
    /// @dev Indicator for determining whether the liquifying of the token pair is enabled
    bool public swapAndLiquifyEnabled = true;
    /// @dev Indicator for determining whether the pump mechanism is enabled
    bool public pumpEnabled = true;

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    /**
     * @param name ERC20 token name
     * @param symbol ERC20 token symbol
     * @param totalSupply ERC20 capped total supply number of tokens with 18 decimals
     * @param fees_, set of fees for dev, liquify, burn and pump mechanism
     * @param routerAddress for creating pair with uniswap v2 router interface
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        Fees memory fees_,
        address routerAddress,
        address routerAddress2
    ) ERC20(name, symbol) Ownable(msg.sender) {
        fees = fees_;

        uniswapV2Router = IUniswapV2Router02(routerAddress);
        uniswapV2Router2 = IUniswapV2Router02(routerAddress2);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );
        uniswapV2Pair2 = IUniswapV2Factory(uniswapV2Router2.factory())
            .createPair(address(this), uniswapV2Router2.WETH());

        _isExcludedFromFee[BURN_ADDRESS] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[owner()] = true;

        _mint(msg.sender, totalSupply);
    }

    receive() external payable {}

    /**
     * @dev See {IAutoPump-setRouterAddress}.
     */
    function setRouterAddress(address newRouter) external onlyOwner {
        emit RouterAddressUpdated(address(uniswapV2Router), newRouter);

        uniswapV2Router = IUniswapV2Router02(newRouter);
        address getPair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(
            address(this),
            uniswapV2Router.WETH()
        );
        uniswapV2Pair = getPair == address(0)
            ? IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
            )
            : getPair;
    }

    /**
     * @dev See {IAutoPump-setRouterAddress2}.
     */
    function setRouterAddress2(address newRouter) external onlyOwner {
        emit RouterAddressUpdated(address(uniswapV2Router2), newRouter);

        uniswapV2Router2 = IUniswapV2Router02(newRouter);
        address getPair = IUniswapV2Factory(uniswapV2Router2.factory()).getPair(
            address(this),
            uniswapV2Router2.WETH()
        );
        uniswapV2Pair2 = getPair == address(0)
            ? IUniswapV2Factory(uniswapV2Router2.factory()).createPair(
                address(this),
                uniswapV2Router2.WETH()
            )
            : getPair;
    }

    /**
     * @dev See {IAutoPump-setPumpThreshold}.
     */
    function setPumpThreshold(uint256 amountToUpdate) external onlyOwner {
        emit PumpThresholdUpdated(pumpEthThreshold, amountToUpdate);

        pumpEthThreshold = amountToUpdate;
    }

    /**
     * @dev See {IAutoPump-setLiquifyThreshold}.
     */
    function setLiquifyThreshold(uint256 amountToUpdate) external onlyOwner {
        emit LiquifyThresholdUpdated(liquifyTokenThreshold, amountToUpdate);

        liquifyTokenThreshold = amountToUpdate;
    }

    /**
     * @dev See {IAutoPump-setExcludeFromFee}.
     */
    function setExcludeFromFee(address account, bool status) public onlyOwner {
        emit ExcludeFromFeeUpdated(account, status);

        _isExcludedFromFee[account] = status;
    }

    /**
     * @dev See {IAutoPump-setSwapAndLiquifyEnabled}.
     */
    function setSwapAndLiquifyEnabled(bool enabled) public onlyOwner {
        emit SwapAndLiquifyUpdated(swapAndLiquifyEnabled, enabled);

        swapAndLiquifyEnabled = enabled;
    }

    /**
     * @dev See {IAutoPump-setPumpEnabled}.
     */
    function setPumpEnabled(bool enabled) public onlyOwner {
        emit PumpUpdated(pumpEnabled, enabled);

        pumpEnabled = enabled;
    }

    /**
     * @dev See {IAutoPump-setFees}.
     */
    function setFees(Fees memory _fees) public onlyOwner {
        emit FeesUpdated(fees, _fees);

        fees = _fees;
    }

    /**
     * @dev overrides _update with adding Liquify, Pump and Fee mechanism to transfer functionality
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        bool passedLiquifyThreshold = balanceOf(address(this)) >
            liquifyTokenThreshold;

        bool passedPumpThreshold = address(this).balance > pumpEthThreshold;

        IUniswapV2Router02 router = uniswapV2Router;
        IUniswapV2Router02 router2 = uniswapV2Router2;

        if (block.timestamp % 2 == 1) {
            router = uniswapV2Router2;
            router2 = uniswapV2Router;
        }

        if (
            passedLiquifyThreshold &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            from != uniswapV2Pair2 &&
            swapAndLiquifyEnabled
        ) {
            _swapAndLiquify(router);
        }
        if (
            passedPumpThreshold &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            from != uniswapV2Pair2 &&
            pumpEnabled
        ) {
            _swapAndPump(router);
        }
        if (!_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            uint256 totalFee = _takeBurnFee(from, value) +
                _takeLiquidifyFee(from, value);
            if (!inSwapAndLiquify) {
                if (from == uniswapV2Pair2 || to == uniswapV2Pair2)
                    router = router2;
                totalFee += _takePumpFee(from, value, router);
            }
            value -= totalFee;
        }
        super._update(from, to, value);
    }

    /**
     * @dev Liquify the token pair with spliting the accumulated tokens to
     * half and providing the liquidity in ETH and AutoPump tokens
     * @dev lockTheSwap that prevent from Pump and Liquify on same update
     */
    function _swapAndLiquify(IUniswapV2Router02 router) private lockTheSwap {
        uint256 half = liquifyTokenThreshold / 2;
        uint256 otherHalf = liquifyTokenThreshold - half;
        uint256 initialBalance = address(this).balance;
        _swapTokensForEth(half, router);
        uint256 receivedEth = address(this).balance - initialBalance;
        _addLiquidity(otherHalf, receivedEth, router);
        emit SwapAndLiquify(half, receivedEth);
    }

    /**
     * @dev Auto Pump mechanism after hitting Pump threshold
     * @dev lockTheSwap that prevent from Pump and Liquify on same update
     */
    function _swapAndPump(IUniswapV2Router02 router) private lockTheSwap {
        _swapEthForTokensAndBurn(pumpEthThreshold, router);
        emit SwapAndPump(pumpEthThreshold);
    }

    /**
     * @dev Used in liquify mechanism for swapping tokens for ETH
     */
    function _swapTokensForEth(
        uint256 tokenAmount,
        IUniswapV2Router02 router
    ) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        _approve(address(this), address(router), tokenAmount);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Used in auto pump for buying tokens with ETH and burning the swapped tokens
     * @dev burning directly is not possible so they will transfer to BURN_ADDRESS first
     */
    function _swapEthForTokensAndBurn(
        uint256 ethAmount,
        IUniswapV2Router02 router
    ) private {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(this);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAmount
        }(0, path, BURN_ADDRESS, block.timestamp);
        super._update(BURN_ADDRESS, address(0), balanceOf(BURN_ADDRESS));
    }

    /**
     * @dev Used in Liquify to provide liquidity to token pair
     */
    function _addLiquidity(
        uint256 tokenAmount,
        uint256 ethAmount,
        IUniswapV2Router02 router
    ) private {
        _approve(address(this), address(router), tokenAmount);
        router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    /**
     * @dev Calculates liquidity fee and transfer it to token address to accumulate
     */
    function _takeLiquidifyFee(
        address from,
        uint256 _amount
    ) private returns (uint256 liquidifyFee) {
        liquidifyFee = (_amount * fees.liquifyFee) / 1e4;
        super._update(from, address(this), liquidifyFee);
    }

    /**
     * @dev Calculates burn fee and burns it directly
     */
    function _takeBurnFee(
        address from,
        uint256 _amount
    ) private returns (uint256 burnFee) {
        burnFee = (_amount * fees.burnFee) / 1e4;
        super._update(from, address(0), burnFee);
    }

    /**
     * @dev Calculates pump fee and swaps immediately to accumulate ETH
     */
    function _takePumpFee(
        address from,
        uint256 _amount,
        IUniswapV2Router02 router
    ) private lockTheSwap returns (uint256 pumpFee) {
        pumpFee = (_amount * fees.pumpFee) / 1e4;
        super._update(from, address(this), pumpFee);
        _swapTokensForEth(pumpFee, router);
    }
}
