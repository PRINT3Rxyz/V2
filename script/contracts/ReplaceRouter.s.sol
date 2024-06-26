// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {Router} from "src/router/Router.sol";
import {Market} from "src/markets/Market.sol";
import {TradeStorage} from "src/positions/TradeStorage.sol";
import {GlobalRewardTracker} from "src/rewards/GlobalRewardTracker.sol";
import {PriceFeed} from "src/oracle/PriceFeed.sol";

contract ReplaceRouter is Script {
    address marketFactory = 0xac5CccF314Db6f3310039484bDf14F774664d4D2;
    address market = 0xa918067e193D16bA9A5AB36270dDe2869892b276;
    address priceFeed = 0x4C3C29132894f2fB032242E52fb16B5A1ede5A04;
    address usdc = 0x9881f8b307CC3383500b432a8Ce9597fAfc73A77;
    address weth = 0xD8eca5111c93EEf563FAB704F2C6A8DD7A12c77D;
    address positionManager = 0xdF1f52F5020DEaF52C52B00367c63928771E7D71;
    address rewardTracker = 0xd076E2748dDD64fc26D0E09154dDD750F8FeBD40;

    address tradeStorage = 0xbfb8d62f829a395DBe27a5983a72FC5F9CA68c11;

    address oldRouter = 0x1246c3E94a18609E683Aa376549E3d9B8d28A8C0;

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
