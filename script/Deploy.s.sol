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
    IHelperConfig.Contracts public helperContracts;

    uint256 internal constant _ROLE_0 = 1 << 0;
    uint256 internal constant _ROLE_1 = 1 << 1;
    uint256 internal constant _ROLE_2 = 1 << 2;
    uint256 internal constant _ROLE_3 = 1 << 3;
    uint256 internal constant _ROLE_4 = 1 << 4;
    uint256 internal constant _ROLE_5 = 1 << 5;
    uint256 internal constant _ROLE_6 = 1 << 6;

    string priceUpdateSource = 'const { Buffer } = await import("node:buffer");'
        "const timestamp = Number(args[0]);" 'const tickers = args.slice(1).join(",");' "if (!secrets.API_KEY) {"
        '  throw new Error("Missing COINMARKETCAP_API_KEY");' "}" "const currentTime = Math.floor(Date.now() / 1000);"
        "let cmcResponse;" "let isLatest;" "if (currentTime - timestamp < 300) {"
        "  const cmcRequest = await Functions.makeHttpRequest({"
        "    url: `https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest`,"
        '    headers: { "X-CMC_PRO_API_KEY": secrets.API_KEY },' "    params: {" "      symbol: tickers," "    },"
        "  });" "  cmcResponse = await cmcRequest;" "  isLatest = true;" "} else {"
        "  const cmcRequest = await Functions.makeHttpRequest({"
        "    url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`,"
        '    headers: { "X-CMC_PRO_API_KEY": secrets.API_KEY },' "    params: {" "      symbol: tickers,"
        "      time_end: timestamp," "    }," "  });" "  cmcResponse = await cmcRequest;" "  isLatest = false;" "}"
        'console.log("Request Success? ", cmcResponse);' "if (cmcResponse.status !== 200) {"
        '  throw new Error("GET Request to CMC API Failed");' "}" "const data = cmcResponse.data.data;"
        "const encodePriceData = async (ticker, priceData, timestamp, isLatest) => {"
        "  const tickerHex = Buffer.alloc(15).fill(0);" "  tickerHex.write(ticker);"
        '  const tickerHexStr = tickerHex.toString("hex");' "  const precisionHex = Buffer.alloc(1);"
        "  precisionHex.writeUInt8(2, 0);" '  const precisionHexStr = precisionHex.toString("hex");'
        "  const quotes = isLatest ? priceData.quote : priceData.quotes;" "  let low, med, high;" "  if (isLatest) {"
        "    low = med = high = Math.round(quotes.USD.price * 100);" "  } else {"
        "    [low, med, high] = getQuotes(quotes);" "    low = Math.round(low * 100);"
        "    med = Math.round(med * 100);" "    high = Math.round(high * 100);" "  }"
        "  const variance = getVariance(low, high);" "  const varianceHex = Buffer.alloc(2);"
        "  varianceHex.writeUInt16LE(variance, 0);" '  const varianceHexStr = varianceHex.toString("hex");'
        '  const timestampHexStr = timestamp.toString(16).padStart(12, "0");'
        '  const priceHexStr = med.toString(16).padStart(16, "0");'
        "  const encodedPriceHex = `${tickerHexStr}${precisionHexStr}${varianceHexStr}${timestampHexStr}${priceHexStr}`;"
        "  return encodedPriceHex;" "};" "const getQuotes = (quotes) => {"
        "  const prices = quotes.map(quote => quote.quote.USD.price);" "  const highPrice = Math.max(...prices);"
        "  const lowPrice = Math.min(...prices);" "  const sortedPrices = prices.slice().sort((a, b) => a - b);"
        "  const medianPrice = sortedPrices.length % 2 === 0 "
        "    ? (sortedPrices[sortedPrices.length / 2 - 1] + sortedPrices[sortedPrices.length / 2]) / 2 "
        "    : sortedPrices[Math.floor(sortedPrices.length / 2)];" "  return [lowPrice, medianPrice, highPrice];" "};"
        "const getVariance = (low, high) => {" "  return Math.round(((high - low) / low) * 10000);" "};"
        'let finalHexStr = "";' 'for (let ticker of tickers.split(",")) {'
        "  const encodedPriceData = await encodePriceData(" "    ticker," "    data[ticker][0]," "    timestamp,"
        "    isLatest" "  );" "  finalHexStr += encodedPriceData;" "}" 'console.log("Final Hex Str: ", finalHexStr);'
        "const arr = new Uint8Array(finalHexStr.length / 2);" "for (let i = 0; i < arr.length; i++) {"
        "  arr[i] = parseInt(finalHexStr.slice(i * 2, i * 2 + 2), 16);" "}" 'console.log("Return Hooray!!! ", arr);'
        "return arr;";
    // Inline entire file -> Update File for Chain
    string cumulativePnlSource = 'const ethers = await import("npm:ethers@6.10.0");'
        'const { Buffer } = await import("node:buffer");' 'const MARKET = "0xa918067e193D16bA9A5AB36270dDe2869892b276";'
        'const MARKET_UTILS = "0xf70b53308d1691ef87f41092f3087d9389eff71a";'
        'const PRICE_FEED = "0x4C3C29132894f2fB032242E52fb16B5A1ede5A04";'
        "const PRECISION_DIVISOR = 10000000000000000000000000000n;" "const MARKET_ABI = [" "  {" '    type: "function",'
        '    name: "getTickers",' '    inputs: [{ name: "_id", type: "bytes32", internalType: "MarketId" }],'
        '    outputs: [{ name: "", type: "string[]", internalType: "string[]" }],' '    stateMutability: "view",' "  },"
        "];" "const MARKET_UTILS_ABI = [" "  {" '    type: "function",' '    name: "getMarketPnl",' "    inputs: ["
        '      { name: "_id", type: "bytes32", internalType: "MarketId" },'
        '      { name: "_market", type: "address", internalType: "address" },'
        '      { name: "_ticker", type: "string", internalType: "string" },'
        '      { name: "_indexPrice", type: "uint256", internalType: "uint256" },'
        '      { name: "_indexBaseUnit", type: "uint256", internalType: "uint256" },'
        '      { name: "_isLong", type: "bool", internalType: "bool" },' "    ],"
        '    outputs: [{ name: "netPnl", type: "int256", internalType: "int256" }],' '    stateMutability: "view",'
        "  }," "];" "const PRICE_FEED_ABI = [" "  {" '    type: "function",' '    name: "tokenDecimals",'
        '    inputs: [{ name: "ticker", type: "string", internalType: "string" }],'
        '    outputs: [{ name: "", type: "uint8", internalType: "uint8" }],' '    stateMutability: "view",' "  }," "];"
        "class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {" "  constructor(url) {" "    super(url);"
        "    this.url = url;" "  }" "  async _send(payload) {" "    let resp = await fetch(this.url, {"
        '      method: "POST",' '      headers: { "Content-Type": "application/json" },'
        "      body: JSON.stringify(payload)," "    });" "    return resp.json();" "  }" "}"
        "const provider = new FunctionsJsonRpcProvider(secrets.RPC_URL);"
        "const market = new ethers.Contract(MARKET, MARKET_ABI, provider);" "const marketUtils = new ethers.Contract("
        "  MARKET_UTILS," "  MARKET_UTILS_ABI," "  provider" ");"
        "const priceFeed = new ethers.Contract(PRICE_FEED, PRICE_FEED_ABI, provider);"
        "const timestamp = Number(args[0]);" "const marketId = args[1];"
        "const tickers = await market.getTickers(marketId);" "const getMedianPrice = async (ticker) => {"
        "  const currentTime = Math.floor(Date.now() / 1000);" "  let cmcResponse;" "  let isLatest;"
        "  if (currentTime - timestamp < 300) {" "    const cmcRequest = await Functions.makeHttpRequest({"
        "      url: `https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest`,"
        '      headers: { "X-CMC_PRO_API_KEY": secrets.API_KEY },' "      params: { symbol: tickers }," "    });"
        "    cmcResponse = await cmcRequest;" "    isLatest = true;" "  } else {"
        "    const cmcRequest = await Functions.makeHttpRequest({"
        "      url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`,"
        '      headers: { "X-CMC_PRO_API_KEY": secrets.API_KEY },'
        "      params: { symbol: tickers, time_end: timestamp }," "    });" "    cmcResponse = await cmcRequest;"
        "    isLatest = false;" "  }" "  if (cmcResponse.status !== 200 || cmcResponse.data.status.error_code !== 0) {"
        '    throw new Error("GET Request to CMC API Failed");' "  }" "  const data = cmcResponse.data.data[ticker][0];"
        "  const quotes = isLatest ? data.quote : data.quotes;" "  let medianPrice;" "  if (isLatest) {"
        "    medianPrice =" "      BigInt(Math.round(quotes.USD.price * 100)) *" "      10000000000000000000000000000n;"
        "  } else {" "    medianPrice =" "      BigInt(Math.round(getQuote(quotes) * 100)) *"
        "      10000000000000000000000000000n;" "  }" "  return medianPrice;" "};"
        "const getBaseUnit = async (ticker) => {" "  const tokenDecimals = await priceFeed.tokenDecimals(ticker);"
        "  const baseUnit = tokenDecimals" "    ? BigInt(10 ** tokenDecimals)" "    : 1000000000000000000n;"
        "  return baseUnit;" "};" "const getQuote = (quotes) => {"
        "  const prices = quotes.map((quote) => quote.quote.USD.price);"
        "  const sortedPrices = prices.slice().sort((a, b) => a - b);" "  const medianPrice ="
        "    sortedPrices.length % 2 === 0" "      ? (sortedPrices[sortedPrices.length / 2 - 1] +"
        "          sortedPrices[sortedPrices.length / 2]) /" "        2"
        "      : sortedPrices[Math.floor(sortedPrices.length / 2)];" "  return medianPrice;" "};"
        "const calculateCumulativePnl = async () => {" "  let cumulativePnl = 0n;" "  for (const ticker of tickers) {"
        "    const medianPrice = await getMedianPrice(ticker);" "    const baseUnit = await getBaseUnit(ticker);"
        "    const pnlLong = await marketUtils.getMarketPnl(" "      marketId," "      MARKET," "      ticker,"
        "      medianPrice," "      baseUnit," "      true" "    );" "    cumulativePnl += pnlLong / PRECISION_DIVISOR;"
        "    const pnlShort = await marketUtils.getMarketPnl(" "      marketId," "      MARKET," "      ticker,"
        "      medianPrice," "      baseUnit," "      false" "    );"
        "    cumulativePnl += pnlShort / PRECISION_DIVISOR;" "  }" "  return {" "    precision: 2,"
        "    timestamp: Math.floor(Date.now() / 1000)," "    cumulativePnl: cumulativePnl," "  };" "};"
        "const formatResult = (result) => {" "  const buffer = Buffer.alloc(23);"
        "  buffer.writeUInt8(result.precision, 0);" "  buffer.writeUIntBE(result.timestamp, 1, 6);"
        "  const pnlBuffer = Buffer.alloc(16);" "  let cumulativePnl = BigInt(result.cumulativePnl);"
        "  if (cumulativePnl < 0) {" "    cumulativePnl = BigInt(2) ** BigInt(127) + cumulativePnl;" "  }"
        "  pnlBuffer.writeBigInt64BE(cumulativePnl, 8);" "  buffer.set(pnlBuffer, 7);"
        '  return buffer.toString("hex");' "};" "const result = await calculateCumulativePnl();"
        "const formattedResult = formatResult(result);" "const arr = new Uint8Array(formattedResult.length / 2);"
        "for (let i = 0; i < arr.length; i++) {" "  arr[i] = parseInt(formattedResult.slice(i * 2, i * 2 + 2), 16);" "}"
        "return arr;";

    bytes public encryptedSecretsUrls =
        hex"50225c593c3142d7097ed73d01e76e8403a61945b3385dda1f5cc171f9c2f193f102fc1aee84ff9127d4813f63b8bfc2eef78704bc45735473152ee9c5af0b010f09c01fa7fb76693985382a0285315c05fc961266b03038f290373e3c5b011b59c6cbe51aef414f39f14d712f404ef894b57b44c13a809de86eaeea2792dcb06a6fb8fa22352a6ee86a26f2b82e076c6b78d7ccde693bba23d838e538f4d1d79f";

    function run() external returns (Contracts memory contracts) {
        helperConfig = new HelperConfig();
        IPriceFeed priceFeed;
        {
            activeNetworkConfig = helperConfig.getActiveNetworkConfig();
            helperContracts = activeNetworkConfig.contracts;
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
        contracts.marketFactory =
            new MarketFactory(activeNetworkConfig.contracts.weth, activeNetworkConfig.contracts.usdc);

        if (activeNetworkConfig.mockFeed) {
            // Deploy a Mock Price Feed contract
            contracts.priceFeed = new MockPriceFeed(
                address(contracts.marketFactory),
                activeNetworkConfig.contracts.weth,
                activeNetworkConfig.contracts.link,
                activeNetworkConfig.contracts.uniV3SwapRouter,
                activeNetworkConfig.contracts.uniV3Factory,
                activeNetworkConfig.subId,
                activeNetworkConfig.donId,
                activeNetworkConfig.contracts.chainlinkRouter
            );
        } else {
            // Deploy a Price Feed Contract
            contracts.priceFeed = new PriceFeed(
                address(contracts.marketFactory),
                activeNetworkConfig.contracts.weth,
                activeNetworkConfig.contracts.link,
                activeNetworkConfig.contracts.uniV3SwapRouter,
                activeNetworkConfig.contracts.uniV3Factory,
                activeNetworkConfig.subId,
                activeNetworkConfig.donId,
                activeNetworkConfig.contracts.chainlinkRouter
            );
        }

        contracts.market = new Market(activeNetworkConfig.contracts.weth, activeNetworkConfig.contracts.usdc);

        contracts.referralStorage = new ReferralStorage(
            activeNetworkConfig.contracts.weth, activeNetworkConfig.contracts.usdc, address(contracts.marketFactory)
        );

        contracts.tradeStorage = new TradeStorage(
            address(contracts.market), address(contracts.referralStorage), address(contracts.priceFeed)
        );

        contracts.tradeEngine = new TradeEngine(address(contracts.tradeStorage), address(contracts.market));

        contracts.rewardTracker = new GlobalRewardTracker(
            activeNetworkConfig.contracts.weth, activeNetworkConfig.contracts.usdc, "Staked BRRR", "sBRRR"
        );

        contracts.positionManager = new PositionManager(
            address(contracts.marketFactory),
            address(contracts.market),
            address(contracts.tradeStorage),
            address(contracts.rewardTracker),
            address(contracts.referralStorage),
            address(contracts.priceFeed),
            address(contracts.tradeEngine),
            activeNetworkConfig.contracts.weth,
            activeNetworkConfig.contracts.usdc
        );

        contracts.router = new Router(
            address(contracts.marketFactory),
            address(contracts.market),
            address(contracts.priceFeed),
            activeNetworkConfig.contracts.usdc,
            activeNetworkConfig.contracts.weth,
            address(contracts.positionManager),
            address(contracts.rewardTracker)
        );

        contracts.feeDistributor = new FeeDistributor(
            address(contracts.marketFactory),
            address(contracts.rewardTracker),
            activeNetworkConfig.contracts.weth,
            activeNetworkConfig.contracts.usdc
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
            address(contracts.feeDistributor),
            msg.sender,
            0.01 ether,
            0.005 ether
        );

        contracts.marketFactory.setFeedValidators(
            activeNetworkConfig.contracts.pyth,
            activeNetworkConfig.contracts.uniV2Factory,
            activeNetworkConfig.contracts.uniV3Factory
        );

        contracts.marketFactory.setRewardTracker(address(contracts.rewardTracker));

        // @audit - dummy values
        contracts.priceFeed.initialize(
            priceUpdateSource,
            cumulativePnlSource,
            185000,
            300_000,
            0.005 ether,
            0.0001 gwei,
            activeNetworkConfig.contracts.nativeLinkUsdFeed, // LINK USD BASE SEPOLIA
            activeNetworkConfig.contracts.sequencerUptimeFeed,
            5 minutes
        );
        contracts.priceFeed.setEncryptedSecretUrls(encryptedSecretsUrls);
        if (!activeNetworkConfig.mockFeed) {
            OwnableRoles(address(contracts.priceFeed)).grantRoles(address(contracts.marketFactory), _ROLE_0);
            OwnableRoles(address(contracts.priceFeed)).grantRoles(address(contracts.router), _ROLE_3);
        }

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

        contracts.positionManager.updateGasEstimates(1 gwei, 1 gwei, 1 gwei, 1 gwei);

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
