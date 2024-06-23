// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";
import {IMarket} from "src/markets/Market.sol";
import {MarketFactory, IMarketFactory} from "src/factory/MarketFactory.sol";
import {PriceFeed, IPriceFeed} from "src/oracle/PriceFeed.sol";
import {TradeStorage, ITradeStorage} from "src/positions/TradeStorage.sol";
import {ReferralStorage} from "src/referrals/ReferralStorage.sol";
import {PositionManager} from "src/router/PositionManager.sol";
import {Router} from "src/router/Router.sol";
import {WETH} from "src/tokens/WETH.sol";
import {Oracle} from "src/oracle/Oracle.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {Position} from "src/positions/Position.sol";
import {MarketUtils} from "src/markets/MarketUtils.sol";
import {GlobalRewardTracker} from "src/rewards/GlobalRewardTracker.sol";
import {FeeDistributor} from "src/rewards/FeeDistributor.sol";
import {MathUtils} from "src/libraries/MathUtils.sol";
import {MarketId} from "src/types/MarketId.sol";
import {TradeEngine} from "src/positions/TradeEngine.sol";
import {IVault} from "src/markets/Vault.sol";
import {LibString} from "src/libraries/LibString.sol";
import {IERC20} from "src/tokens/interfaces/IERC20.sol";
import {IPyth} from "@pyth/contracts/IPyth.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {PythStructs} from "@pyth/contracts/PythStructs.sol";
import {IERC20Metadata} from "src/tokens/interfaces/IERC20Metadata.sol";
import {Casting} from "src/libraries/Casting.sol";

contract TestPositions is Test {
    using LibString for bytes15;
    using Casting for int256;
    using Casting for int32;
    using Casting for int64;

    MarketFactory marketFactory;
    PriceFeed priceFeed;
    ITradeStorage tradeStorage;
    ReferralStorage referralStorage;
    PositionManager positionManager;
    TradeEngine tradeEngine;
    Router router;
    address OWNER;
    IMarket market;
    IVault vault;
    FeeDistributor feeDistributor;
    GlobalRewardTracker rewardTracker;

    address weth;
    address usdc;
    address link;

    MarketId marketId;

    string ethTicker = "ETH";
    string usdcTicker = "USDC";
    string[] tickers;

    address USER = makeAddr("USER");
    address USER1 = makeAddr("USER1");
    address USER2 = makeAddr("USER2");

    uint8[] precisions;
    uint16[] variances;
    uint48[] timestamps;
    uint64[] meds;

    /**
     * ==================================== Contract Vars ====================================
     */
    uint8 private constant PRICE_DECIMALS = 30;
    uint8 private constant CHAINLINK_DECIMALS = 8;

    function setUp() public {
        Deploy deploy = new Deploy();
        Deploy.Contracts memory contracts = deploy.run();

        marketFactory = contracts.marketFactory;
        vm.label(address(marketFactory), "marketFactory");

        priceFeed = PriceFeed(address(contracts.priceFeed));
        vm.label(address(priceFeed), "priceFeed");

        referralStorage = contracts.referralStorage;
        vm.label(address(referralStorage), "referralStorage");

        positionManager = contracts.positionManager;
        vm.label(address(positionManager), "positionManager");

        router = contracts.router;
        vm.label(address(router), "router");

        market = contracts.market;
        vm.label(address(market), "market");

        tradeStorage = contracts.tradeStorage;
        vm.label(address(tradeStorage), "tradeStorage");

        tradeEngine = contracts.tradeEngine;
        vm.label(address(tradeEngine), "tradeEngine");

        feeDistributor = contracts.feeDistributor;
        vm.label(address(feeDistributor), "feeDistributor");

        OWNER = contracts.owner;
        (weth, usdc, link,,,) = deploy.helperContracts();
        tickers.push(ethTicker);
        tickers.push(usdcTicker);
        // Pass some time so block timestamp isn't 0
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
    }

    receive() external payable {}

    // Call isSequencerUp for a number of times
    function test_sequencer_uptime_feed(uint48 _randomTimestamp) public {
        _randomTimestamp = uint48(bound(_randomTimestamp, block.timestamp - 365 days, block.timestamp));
        vm.warp(_randomTimestamp);
        Oracle.isSequencerUp(priceFeed);
    }

    function test_validating_chainlink_feeds() public view {
        // Native Link USD Feed
        Oracle.isValidChainlinkFeed(0x17CAb8FE31E32f08326e5E27412894e49B0f9D65);
        // Apt USD
        Oracle.isValidChainlinkFeed(0x88a98431C25329AA422B21D147c1518b34dD36F4);
        // Aero USD
        Oracle.isValidChainlinkFeed(0x4EC5970fC728C5f65ba413992CD5fF6FD70fcfF0);
        // Degen USD
        Oracle.isValidChainlinkFeed(0xE62BcE5D7CB9d16AB8b4D622538bc0A50A5799c2);
        // Wif USD
        Oracle.isValidChainlinkFeed(0x674940e1dBf7FD841b33156DA9A88afbD95AaFBa);
    }

    function test_validating_pyth_feeds() public view {
        IPyth pyth = IPyth(0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a);
        // SOL
        Oracle.isValidPythFeed(pyth, 0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d);
        // SEI
        Oracle.isValidPythFeed(pyth, 0x53614f1cb0c031d4af66c04cb9c756234adad0e1cee85303795091499a4084eb);
        // SHIB
        Oracle.isValidPythFeed(pyth, 0xf0d57deca57b3da2fe63a493f4c25925fdfd8edf834b20f93e1f84dbd1504d4a);
        // MATIC
        Oracle.isValidPythFeed(pyth, 0x5de33a9112c2b700b8d30b8a3402c103578ccfa2765696471cc672bd5cf6ac52);
        // FTM
        Oracle.isValidPythFeed(pyth, 0x5c6c0d2386e3352356c3ab84434fafb5ea067ac2678a38a338c4a69ddc4bdb0c);
        // BTC
        Oracle.isValidPythFeed(pyth, 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43);
    }

    function test_providing_invalid_feed_types(uint8 _feedType) public {
        vm.assume(_feedType > 1);
        vm.expectRevert();
        Oracle.validateFeedType(IPriceFeed.FeedType(_feedType));
    }

    IPriceFeed.SecondaryStrategy btcStrategy = IPriceFeed.SecondaryStrategy({
        exists: true,
        feedType: IPriceFeed.FeedType.CHAINLINK,
        feedAddress: 0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F,
        feedId: 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43
    });
    IPriceFeed.SecondaryStrategy ethStrategy = IPriceFeed.SecondaryStrategy({
        exists: true,
        feedType: IPriceFeed.FeedType.CHAINLINK,
        feedAddress: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70,
        feedId: 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace
    });
    IPriceFeed.SecondaryStrategy solStrategy = IPriceFeed.SecondaryStrategy({
        exists: true,
        feedType: IPriceFeed.FeedType.CHAINLINK,
        feedAddress: 0x975043adBb80fc32276CbF9Bbcfd4A601a12462D,
        feedId: 0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d
    });

    // Query the same price feed for chainlink and pyth and assert approx eq abs
    function test_chainlink_and_pyth_feeds_return_valid_scaled_results() public {
        uint256 btcPrice = _getChainlinkPrice(btcStrategy);
        btcStrategy.feedType = IPriceFeed.FeedType.PYTH;
        uint256 btcPythPrice = _getPythPrice(btcStrategy);
        // Prices within $10 of eachother
        assertGt(btcPrice, 60_000e30);
        assertGt(btcPythPrice, 60_000e30);
        assertApproxEqAbs(btcPrice, btcPythPrice, 500e30);

        uint256 ethPrice = _getChainlinkPrice(ethStrategy);
        ethStrategy.feedType = IPriceFeed.FeedType.PYTH;
        uint256 ethPythPrice = _getPythPrice(ethStrategy);
        // Prices within $10 of eachother
        assertGt(ethPrice, 3_000e30);
        assertGt(ethPythPrice, 3_000e30);
        assertApproxEqAbs(ethPrice, ethPythPrice, 100e30);

        uint256 solPrice = _getChainlinkPrice(solStrategy);
        solStrategy.feedType = IPriceFeed.FeedType.PYTH;
        uint256 solPythPrice = _getPythPrice(solStrategy);
        // Prices within $10 of eachother
        assertGt(solPrice, 100e30);
        assertGt(solPythPrice, 100e30);
        assertApproxEqAbs(solPrice, solPythPrice, 10e30);
    }

    /**
     * ================================== Internal Functions ==================================
     */
    function _getChainlinkPrice(IPriceFeed.SecondaryStrategy memory _strategy) private view returns (uint256 price) {
        if (_strategy.feedType != IPriceFeed.FeedType.CHAINLINK) revert("Invalid Ref Query");
        // Get the price feed address from the ticker
        AggregatorV2V3Interface chainlinkFeed = AggregatorV2V3Interface(_strategy.feedAddress);
        // Query the feed for the price
        int256 signedPrice = chainlinkFeed.latestAnswer();
        // Convert the price from int256 to uint256 and expand decimals to 30 d.p
        price = signedPrice.abs() * (10 ** (PRICE_DECIMALS - CHAINLINK_DECIMALS));
    }

    // Need the Pyth address and the bytes32 id for the ticker
    function _getPythPrice(IPriceFeed.SecondaryStrategy memory _strategy) private view returns (uint256 price) {
        if (_strategy.feedType != IPriceFeed.FeedType.PYTH) revert("Invalid Ref Query");
        // Query the Pyth feed for the price
        IPyth pythFeed = IPyth(priceFeed.pyth());
        PythStructs.Price memory pythData = pythFeed.getEmaPriceUnsafe(_strategy.feedId);
        // Expand the price to 30 d.p
        uint256 exponent = PRICE_DECIMALS - pythData.expo.abs();
        price = pythData.price.abs() * (10 ** exponent);
    }
}
