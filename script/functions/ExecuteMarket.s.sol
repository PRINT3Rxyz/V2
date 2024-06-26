// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {MarketFactory} from "src/factory/MarketFactory.sol";

contract ExecuteMarket is Script {
    MarketFactory public marketFactory = MarketFactory(0xac5CccF314Db6f3310039484bDf14F774664d4D2);

    function run() public {
        bytes32[] memory requestKeys = marketFactory.getRequestKeys();
        bytes32 requestKey = requestKeys[requestKeys.length - 1];
        vm.broadcast();
        marketFactory.executeMarketRequest(requestKey);
    }
}
