// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {MarketFactory} from "src/factory/MarketFactory.sol";

contract ExecuteMarket is Script {
    MarketFactory public marketFactory = MarketFactory(0xac5CccF314Db6f3310039484bDf14F774664d4D2);
    // Replace with RequestKey from CreateMarket script console
    bytes32 requestKey = 0xa8b010e4cce0ca14448a7cc98095c44ce23e39e4fe59f9d34954275f9b9c96f1;

    function run() public {
        vm.broadcast();
        marketFactory.executeMarketRequest(requestKey);
    }
}
