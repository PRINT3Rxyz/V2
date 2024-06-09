// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import "forge-std/Test.sol";
import {MarketFactory, IMarketFactory} from "src/factory/MarketFactory.sol";
import {PriceFeed, IPriceFeed} from "src/oracle/PriceFeed.sol";
import {Oracle} from "src/oracle/Oracle.sol";

contract CreateMarket is Script {
    /**
     * 1. Call createNewMarket with given Input Struct -> Returns Request Key
     * 2. Request Pricing for the Asset in question from Chainlink Functions --> Make Sure Functions is set up
     * 3.
     */
    MarketFactory public marketFactory = MarketFactory(0xC56A5aB4B8d3e76b8841eAf92ec91e2E67838085);
    PriceFeed public priceFeed = PriceFeed(0x4bDF5f4b07d4332397b754BC1ac24502f4D54a7D);

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
