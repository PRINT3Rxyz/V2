// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import "forge-std/Test.sol";
import {MarketFactory, IMarketFactory} from "src/factory/MarketFactory.sol";
import {PriceFeed, IPriceFeed} from "src/oracle/PriceFeed.sol";
import {Oracle} from "src/oracle/Oracle.sol";

contract CreateMarket is Script {
    MarketFactory public marketFactory = MarketFactory(0xac5CccF314Db6f3310039484bDf14F774664d4D2);
    PriceFeed public priceFeed = PriceFeed(0x1E6d3A7a3e080817d0BA3E9730766EF5C8A8c1Ad);

    function run() public {
        uint256 requestCost = marketFactory.marketCreationFee() + Oracle.estimateRequestCost(priceFeed);

        IPriceFeed.SecondaryStrategy memory secondaryStrategy = IPriceFeed.SecondaryStrategy({
            exists: true,
            feedType: IPriceFeed.FeedType.CHAINLINK,
            feedAddress: 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1,
            feedId: bytes32(0),
            merkleProof: new bytes32[](0)
        });

        IMarketFactory.Input memory input = IMarketFactory.Input({
            isMultiAsset: true,
            indexTokenTicker: "ETH",
            marketTokenName: "BRRR-LP",
            marketTokenSymbol: "BRRR",
            strategy: secondaryStrategy
        });
        vm.broadcast();
        bytes32 requestKey = marketFactory.createNewMarket{value: requestCost}(input);
        console2.log("Request Key: ");
        console.logBytes32(requestKey);
    }
}
