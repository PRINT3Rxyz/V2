// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {MarketFactory} from "src/factory/MarketFactory.sol";
import {Market} from "src/markets/Market.sol";
import {TradeStorage} from "src/positions/TradeStorage.sol";
import {TradeEngine} from "src/positions/TradeEngine.sol";
import {PositionManager} from "src/router/PositionManager.sol";
import {Router} from "src/router/Router.sol";
import {IPriceFeed} from "src/oracle/interfaces/IPriceFeed.sol";

contract ReplacePriceFeed is Script {
    MarketFactory marketFactory;
    Market market;
    TradeStorage tradeStorage;
    TradeEngine tradeEngine;
    PositionManager positionManager;
    Router router;

    IPriceFeed newPriceFeed;

    function run() public {
        vm.startBroadcast();
        marketFactory.updatePriceFeed(newPriceFeed);
        market.updatePriceFeed(newPriceFeed);
        tradeStorage.updatePriceFeed(newPriceFeed);
        tradeEngine.updatePriceFeed(newPriceFeed);
        positionManager.updatePriceFeed(newPriceFeed);
        router.updatePriceFeed(newPriceFeed);
        vm.stopBroadcast();
    }
}
