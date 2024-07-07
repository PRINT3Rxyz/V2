// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {Router} from "src/router/Router.sol";
import {Market} from "src/markets/Market.sol";
import {TradeStorage} from "src/positions/TradeStorage.sol";
import {GlobalRewardTracker} from "src/rewards/GlobalRewardTracker.sol";
import {PriceFeed} from "src/oracle/PriceFeed.sol";

contract ReplaceRouter is Script {
    address marketFactory = 0x516dC01DD2D76E3C3576621b28Eba05c7df61335;
    address market = 0xF9271C5C66F1C29FB48Bcd6bba5350df80160887;
    address priceFeed = 0xD6486A71312e4Ee14224b1AD8402099AD80f5837;
    address usdc = 0x9881f8b307CC3383500b432a8Ce9597fAfc73A77;
    address weth = 0x4200000000000000000000000000000000000006;
    address positionManager = 0xF7bC9A70A048AB4111D39f6893c1fE4fB4d5B51D;
    address rewardTracker = 0x10d8766f5155AdD3d629ddf44b7f1e34De0a4667;

    address tradeStorage = 0x9C4C333B6A43bCfb12a7d8fc76Ad8EF957C469Ec;

    address oldRouter = 0x38B0Cf9DB27DcDb23Cb44E3DC3b6c44150126085;

    uint256 internal constant _ROLE_3 = 1 << 3;

    function run() public {
        vm.startBroadcast();
        // deploy new router
        Router router = new Router(marketFactory, market, priceFeed, usdc, weth, positionManager, rewardTracker);
        // revoke role 3 from market for old router and add for new router
        Market(market).revokeRoles(oldRouter, _ROLE_3);
        Market(market).grantRoles(address(router), _ROLE_3);
        // revoke role 3 from tradeStorage for old router and add for new router
        TradeStorage(tradeStorage).revokeRoles(oldRouter, _ROLE_3);
        TradeStorage(tradeStorage).grantRoles(address(router), _ROLE_3);
        // revoke role 3 from pricefeed for old router and add for new router
        PriceFeed(priceFeed).revokeRoles(oldRouter, _ROLE_3);
        PriceFeed(priceFeed).grantRoles(address(router), _ROLE_3);
        // setHandler for rewardTracker for new router and remove for old router
        GlobalRewardTracker(rewardTracker).setHandler(address(router), true);
        GlobalRewardTracker(rewardTracker).setHandler(oldRouter, false);
        vm.stopBroadcast();
    }
}
