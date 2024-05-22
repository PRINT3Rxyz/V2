// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {HelperConfig, IHelperConfig} from "./HelperConfig.s.sol";
import {MarketFactory} from "../src/factory/MarketFactory.sol";
import {PriceFeed, IPriceFeed} from "../src/oracle/PriceFeed.sol";
import {MockPriceFeed} from "../test/mocks/MockPriceFeed.sol";
import {TradeStorage} from "../src/positions/TradeStorage.sol";
import {ReferralStorage} from "../src/referrals/ReferralStorage.sol";
import {PositionManager} from "../src/router/PositionManager.sol";
import {Router} from "../src/router/Router.sol";
import {IMarket} from "../src/markets/interfaces/IMarket.sol";
import {Oracle} from "../src/oracle/Oracle.sol";
import {FeeDistributor} from "../src/rewards/FeeDistributor.sol";
import {GlobalRewardTracker} from "../src/rewards/GlobalRewardTracker.sol";
import {Pool} from "../src/markets/Pool.sol";
import {OwnableRoles} from "../src/auth/OwnableRoles.sol";
import {TradeEngine} from "../src/positions/TradeEngine.sol";
import {Market} from "../src/markets/Market.sol";

contract Deploy is Script {
    IHelperConfig public helperConfig;

    struct Contracts {
        MarketFactory marketFactory;
        Market market;
        TradeStorage tradeStorage;
        TradeEngine tradeEngine;
        IPriceFeed priceFeed; // Deployed in Helper Config
        ReferralStorage referralStorage;
        PositionManager positionManager;
        Router router;
        FeeDistributor feeDistributor;
        GlobalRewardTracker rewardTracker;
        address owner;
    }

    IHelperConfig.NetworkConfig public activeNetworkConfig;

    uint256 internal constant _ROLE_0 = 1 << 0;
    uint256 internal constant _ROLE_1 = 1 << 1;
    uint256 internal constant _ROLE_2 = 1 << 2;
    uint256 internal constant _ROLE_3 = 1 << 3;
    uint256 internal constant _ROLE_4 = 1 << 4;
    uint256 internal constant _ROLE_5 = 1 << 5;
    uint256 internal constant _ROLE_6 = 1 << 6;

    // Inline entire file
    string priceUpdateSource = 'const { Buffer } = await import("node:buffer");'
        "const timestampUnix = Number(args[0]);" "const timeStart = timestampUnix - 1;" "const timeEnd = timestampUnix;"
        'const tickers = args.slice(1).join(",");' "if (!secrets.apiKey) {" "  throw new Error("
        '    "COINMARKETCAP_API_KEY environment variable not set for CoinMarketCap API. Get a free key from https://coinmarketcap.com/api/"'
        "  );" "}" "const cmcRequest = await Functions.makeHttpRequest({"
        "  url: `https://pro-api.coinmarketcap.com/v2/cryptocurrency/ohlcv/historical`," "  headers: {"
        '    "Content-Type": "application/json",' '    "X-CMC_PRO_API_KEY": secrets.apiKey,' "  }," "  params: {"
        "    symbol: tickers," "    time_start: timeStart," "    time_end: timeEnd," "  }," "});"
        'console.log("Cmc Request: ", cmcRequest);' "const cmcResponse = await cmcRequest;"
        "if (cmcResponse.status !== 200) {" '  throw new Error("GET Request to CMC API Failed");' "}"
        "const data = cmcResponse.data.data;" "// Function to aggregate quotes" "const aggregateQuotes = (quotes) => {"
        "  const validQuotes = quotes.filter((quote) => quote.quote && quote.quote.USD);"
        "  const totalQuotes = validQuotes.length;" "  if (totalQuotes === 0) {"
        "    return { open: 0, high: 0, low: 0, close: 0 };" "  }" "  const aggregated = validQuotes.reduce("
        "    (acc, quote) => {" "      acc.open += quote.quote.USD.open;" "      acc.high += quote.quote.USD.high;"
        "      acc.low += quote.quote.USD.low;" "      acc.close += quote.quote.USD.close;" "      return acc;" "    },"
        "    { open: 0, high: 0, low: 0, close: 0 }" "  );" "  return {" "    open: aggregated.open / totalQuotes,"
        "    high: aggregated.high / totalQuotes," "    low: aggregated.low / totalQuotes,"
        "    close: aggregated.close / totalQuotes," "  };" "};"
        "const filteredData = Object.keys(data).reduce((acc, key) => {" "  const assets = data[key];"
        "  if (assets.length > 0) {" "    const highestMarketCapAsset = assets[0]; // Take the first asset"
        "    highestMarketCapAsset.aggregatedQuotes = aggregateQuotes(" "      highestMarketCapAsset.quotes" "    );"
        "    acc.push(highestMarketCapAsset);" "  }" "  return acc;" "}, []);"
        "    const encodedPrices = filteredData.reduce((acc, tokenData) => {"
        "  const { symbol, aggregatedQuotes } = tokenData;" "  const { open, high, low, close } = aggregatedQuotes;"
        "  // Encoding ticker to exactly 15 bytes with padding" "  const tickerBuffer = Buffer.alloc(15);"
        "  tickerBuffer.write(symbol);" "  const ticker = new Uint8Array(tickerBuffer);"
        "  const precision = new Uint8Array(1);" "  precision[0] = 2; // Assuming 2 decimal places"
        "  const varianceValue = Math.round(((high - low) / low) * 10000);" "  const variance = new Uint8Array(2);"
        "  new DataView(variance.buffer).setUint16(0, varianceValue);"
        "  // Correct timestamp conversion to 6-byte array" "  const timestampSeconds = BigInt(args[0]);"
        "  const timestampBuf = new Uint8Array(6);" "  for (let i = 0; i < 6; i++) {"
        "    timestampBuf[5 - i] = Number(" "      (timestampSeconds >> BigInt(i * 8)) & BigInt(0xff)" "    );" "  }"
        "const medianPriceValue = BigInt(Math.round(((open + close) / 2) * 100)); // Ensure correct scaling"
        "const medianPrice = new Uint8Array(8);" "new DataView(medianPrice.buffer).setBigUint64(0, medianPriceValue);"
        "const encoded = new Uint8Array([" "...ticker," "...precision," "...variance," "...timestampBuf,"
        "...medianPrice," "]);" "acc.push(encoded);" "return acc;" "}, []);"
        "const result = encodedPrices.reduce((acc, bytes) => {"
        "const newBuffer = new Uint8Array(acc.length + bytes.length);" "newBuffer.set(acc);"
        "newBuffer.set(bytes, acc.length);" "return newBuffer;" "}, new Uint8Array());"
        'return Buffer.from(result, "hex")';
    // Inline entire file
    string cumulativePnlSource;

    function run() external returns (Contracts memory contracts) {
        helperConfig = new HelperConfig();
        IPriceFeed priceFeed;
        {
            (activeNetworkConfig) = helperConfig.getActiveNetworkConfig();
        }

        vm.startBroadcast();

        contracts = Contracts(
            MarketFactory(address(0)),
            Market(address(0)),
            TradeStorage(address(0)),
            TradeEngine(address(0)),
            priceFeed,
            ReferralStorage(payable(address(0))),
            PositionManager(payable(address(0))),
            Router(payable(address(0))),
            FeeDistributor(address(0)),
            GlobalRewardTracker(address(0)),
            msg.sender
        );

        /**
         * ============ Deploy Contracts ============
         */
        contracts.marketFactory = new MarketFactory(activeNetworkConfig.weth, activeNetworkConfig.usdc);

        if (activeNetworkConfig.mockFeed) {
            // Deploy a Mock Price Feed contract
            contracts.priceFeed = new MockPriceFeed(
                address(contracts.marketFactory),
                activeNetworkConfig.weth,
                activeNetworkConfig.link,
                activeNetworkConfig.uniV3SwapRouter,
                activeNetworkConfig.uniV3Factory,
                activeNetworkConfig.subId,
                activeNetworkConfig.donId,
                activeNetworkConfig.chainlinkRouter
            );
        } else {
            // Deploy a Price Feed Contract
            contracts.priceFeed = new PriceFeed(
                address(contracts.marketFactory),
                activeNetworkConfig.weth,
                activeNetworkConfig.link,
                activeNetworkConfig.uniV3SwapRouter,
                activeNetworkConfig.uniV3Factory,
                activeNetworkConfig.subId,
                activeNetworkConfig.donId,
                activeNetworkConfig.chainlinkRouter
            );
        }

        contracts.market = new Market(activeNetworkConfig.weth, activeNetworkConfig.usdc);

        contracts.referralStorage =
            new ReferralStorage(activeNetworkConfig.weth, activeNetworkConfig.usdc, address(contracts.marketFactory));

        contracts.tradeStorage = new TradeStorage(
            address(contracts.market), address(contracts.referralStorage), address(contracts.priceFeed)
        );

        contracts.tradeEngine = new TradeEngine(address(contracts.tradeStorage), address(contracts.market));

        contracts.rewardTracker =
            new GlobalRewardTracker(activeNetworkConfig.weth, activeNetworkConfig.usdc, "Staked BRRR", "sBRRR");

        contracts.positionManager = new PositionManager(
            address(contracts.marketFactory),
            address(contracts.market),
            address(contracts.rewardTracker),
            address(contracts.referralStorage),
            address(contracts.priceFeed),
            address(contracts.tradeEngine),
            activeNetworkConfig.weth,
            activeNetworkConfig.usdc
        );

        contracts.router = new Router(
            address(contracts.marketFactory),
            address(contracts.market),
            address(contracts.priceFeed),
            activeNetworkConfig.usdc,
            activeNetworkConfig.weth,
            address(contracts.positionManager),
            address(contracts.rewardTracker)
        );

        contracts.feeDistributor = new FeeDistributor(
            address(contracts.marketFactory),
            address(contracts.rewardTracker),
            activeNetworkConfig.weth,
            activeNetworkConfig.usdc
        );

        /**
         * ============ Set Up Contracts ============
         */
        Pool.Config memory defaultMarketConfig = Pool.Config({
            maxLeverage: 100, // 100x
            maintenanceMargin: 50, // 0.5%
            reserveFactor: 2000, // 20%
            // Skew Scale = Skew for Max Velocity
            maxFundingVelocity: 900, // 9% per day
            skewScale: 1_000_000, // 1 Mil USD
            // Should never be 0
            // Percentages up to 100% (10000)
            positiveLiquidityScalar: 10000,
            negativeLiquidityScalar: 10000
        });

        contracts.marketFactory.initialize(
            defaultMarketConfig,
            address(contracts.market),
            address(contracts.tradeStorage),
            address(contracts.tradeEngine),
            address(contracts.priceFeed),
            address(contracts.referralStorage),
            address(contracts.positionManager),
            address(contracts.router),
            address(contracts.feeDistributor),
            msg.sender,
            0.01 ether,
            0.005 ether
        );

        contracts.marketFactory.setFeedValidators(
            activeNetworkConfig.chainlinkFeedRegistory,
            activeNetworkConfig.pyth,
            activeNetworkConfig.uniV2Factory,
            activeNetworkConfig.uniV3Factory
        );

        contracts.marketFactory.setRewardTracker(address(contracts.rewardTracker));

        // @audit - dummy values
        contracts.priceFeed.initialize(
            priceUpdateSource,
            cumulativePnlSource,
            0.0001 gwei,
            300_000,
            0.0001 gwei,
            0.0001 gwei,
            address(0),
            address(0),
            30 seconds
        );

        contracts.market.initialize(
            address(contracts.tradeStorage), address(contracts.priceFeed), address(contracts.marketFactory)
        );
        contracts.market.grantRoles(address(contracts.positionManager), _ROLE_1);
        contracts.market.grantRoles(address(contracts.router), _ROLE_3);
        contracts.market.grantRoles(address(contracts.tradeEngine), _ROLE_6);

        contracts.tradeStorage.initialize(address(contracts.tradeEngine), address(contracts.marketFactory));
        contracts.tradeStorage.grantRoles(address(contracts.positionManager), _ROLE_1);
        contracts.tradeStorage.grantRoles(address(contracts.router), _ROLE_3);

        contracts.tradeEngine.initialize(
            address(contracts.priceFeed),
            address(contracts.referralStorage),
            address(contracts.positionManager),
            2e30,
            0.05e18,
            0.1e18,
            0.001e18,
            0.1e18
        );
        contracts.tradeEngine.grantRoles(address(contracts.tradeStorage), _ROLE_4);

        contracts.positionManager.updateGasEstimates(180000 gwei, 180000 gwei, 180000 gwei, 180000 gwei);

        contracts.referralStorage.setTier(0, 0.05e18);
        contracts.referralStorage.setTier(1, 0.1e18);
        contracts.referralStorage.setTier(2, 0.15e18);
        contracts.referralStorage.grantRoles(address(contracts.tradeEngine), _ROLE_6);

        contracts.rewardTracker.grantRoles(address(contracts.marketFactory), _ROLE_0);
        contracts.rewardTracker.initialize(address(contracts.feeDistributor));
        contracts.rewardTracker.setHandler(address(contracts.positionManager), true);
        contracts.rewardTracker.setHandler(address(contracts.router), true);

        contracts.feeDistributor.grantRoles(address(contracts.marketFactory), _ROLE_0);

        // Transfer ownership to caller --> for testing
        contracts.marketFactory.transferOwnership(msg.sender);
        if (!activeNetworkConfig.mockFeed) OwnableRoles(address(contracts.priceFeed)).transferOwnership(msg.sender);
        contracts.referralStorage.transferOwnership(msg.sender);
        contracts.positionManager.transferOwnership(msg.sender);
        contracts.router.transferOwnership(msg.sender);
        contracts.feeDistributor.transferOwnership(msg.sender);
        contracts.rewardTracker.transferOwnership(msg.sender);

        vm.stopBroadcast();

        return contracts;
    }
}
