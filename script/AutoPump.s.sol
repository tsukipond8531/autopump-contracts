// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {
    UNISWAP_V2_ROUTER02,
    SUSHISWAP_V2_ROUTER02
} from "test/utils/constant_eth.sol";

import {AutoPump, IAutoPump} from "../src/AutoPump.sol";

contract DeployScript is Script {

    uint256 totalSupply = 1e12 ether;
    uint256 burnFee = 5;
    uint256 liqFee = 2;
    uint256 pumpFee = 3;
    IAutoPump.Fees fees = IAutoPump.Fees(burnFee, pumpFee, liqFee);

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        new AutoPump("AutoPump", "AUTO", totalSupply, fees, UNISWAP_V2_ROUTER02, SUSHISWAP_V2_ROUTER02);

        vm.stopBroadcast();
    }
}
