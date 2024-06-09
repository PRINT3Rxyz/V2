// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {MarketFactory} from "src/factory/MarketFactory.sol";

contract ExecuteMarket is Script {
    MarketFactory public marketFactory = MarketFactory(0xC56A5aB4B8d3e76b8841eAf92ec91e2E67838085);
    bytes32 requestKey = bytes32(0);

    function run() public {
        vm.broadcast();
        marketFactory.executeMarketRequest(requestKey);
    }
}
