// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {MarketFactory, IMarketFactory} from "src/factory/MarketFactory.sol";
import {PriceFeed, IPriceFeed} from "src/oracle/PriceFeed.sol";
import {Oracle} from "src/oracle/Oracle.sol";

contract CreateMarket is Script {
    MarketFactory public marketFactory = MarketFactory(0x700AC8E71a9C7B518ACF3c7c93e3f0284D23315b);
    PriceFeed public priceFeed = PriceFeed(0x1887750E04fCC02B74897E417e0a10c2741A5E48);

    // Get Request from MarketRequested(bytes32 indexed requestKey, string indexed indexTokenTicker)

    function run() public {
        vm.startBroadcast();
        uint256 requestCost = marketFactory.marketCreationFee() + Oracle.estimateRequestCost(address(priceFeed));

        IPriceFeed.SecondaryStrategy memory secondaryStrategy = IPriceFeed.SecondaryStrategy({
            exists: false,
            feedType: IPriceFeed.FeedType.CHAINLINK,
            feedAddress: address(0),
            feedId: bytes32(0)
        });

        IMarketFactory.Input memory input = IMarketFactory.Input({
            indexTokenTicker: "SLERF",
            marketTokenName: "SLERF-LP",
            marketTokenSymbol: "SLERF-BRRR",
            maxLeverage: 1000,
            strategy: secondaryStrategy
        });
        marketFactory.createNewMarket{value: 10000846269629500}(input);
        vm.stopBroadcast();
    }
}
