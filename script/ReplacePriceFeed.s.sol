// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {MarketFactory} from "src/factory/MarketFactory.sol";
import {Market} from "src/markets/Market.sol";
import {TradeStorage} from "src/positions/TradeStorage.sol";
import {TradeEngine} from "src/positions/TradeEngine.sol";
import {PositionManager} from "src/router/PositionManager.sol";
import {Router} from "src/router/Router.sol";
import {PriceFeed, IPriceFeed} from "src/oracle/PriceFeed.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";

contract ReplacePriceFeed is Script {
    MarketFactory marketFactory = MarketFactory(0xac5CccF314Db6f3310039484bDf14F774664d4D2);
    Market market = Market(0xa918067e193D16bA9A5AB36270dDe2869892b276);
    TradeStorage tradeStorage = TradeStorage(0xbfb8d62f829a395DBe27a5983a72FC5F9CA68c11);
    TradeEngine tradeEngine = TradeEngine(0x091AEeA38a7dE33D22a4c5a4bF7366df573245B2);
    PositionManager positionManager = PositionManager(payable(0xdF1f52F5020DEaF52C52B00367c63928771E7D71));
    Router router = Router(payable(0xC656197971FAd28D5F8C7F5424af55ed0f10D753));

    address functionsRouter = 0xf9B8fc078197181C841c296C876945aaa425B278;
    address weth = 0xD8eca5111c93EEf563FAB704F2C6A8DD7A12c77D;
    address link = 0xE4aB69C077896252FAFBD49EFD26B5D171A32410;
    address uniV3Router = 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4;
    address uniV3Factory = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address sequencerUptimeFeed = address(0);
    uint64 subId = 54;
    bytes32 donId = 0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000;

    uint256 private constant _ROLE_0 = 1 << 0;

    // Inline entire file
    string priceUpdateSource = 'const { Buffer } = await import("node:buffer");'
        "const timestamp = Number(args[0]);" 'const tickers = args.slice(1).join(",");' "if (!secrets.apiKey) {"
        '  throw new Error("Missing COINMARKETCAP_API_KEY");' "}" "const currentTime = Math.floor(Date.now() / 1000);"
        "let cmcResponse;" "let isLatest;"
        "// If its been < 5 minutes since request, fetch latest prices (lower latency)"
        "if (currentTime - timestamp < 300) {" "  const cmcRequest = await Functions.makeHttpRequest({"
        "    url: `https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest`,"
        '    headers: { "X-CMC_PRO_API_KEY": secrets.apiKey },' "    params: {" "      symbol: tickers," "    },"
        "  });" "  cmcResponse = await cmcRequest;" "  isLatest = true;" "} else {"
        "  const cmcRequest = await Functions.makeHttpRequest({"
        "    url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`,"
        '    headers: { "X-CMC_PRO_API_KEY": secrets.apiKey },' "    params: {" "      symbol: tickers,"
        "      time_end: timestamp," "    }," "  });" "  cmcResponse = await cmcRequest;" "  isLatest = false;" "}"
        "const cmcRequest = await Functions.makeHttpRequest({"
        "  url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`," "  headers: {"
        '    "Content-Type": "application/json",' '    "X-CMC_PRO_API_KEY": secrets.apiKey,' "  }," "  params: {"
        "    symbol: tickers," "    time_end: timestamp," "  }," "});" "if (cmcResponse.status !== 200) {"
        '  throw new Error("GET Request to CMC API Failed");' "}" "const data = cmcResponse.data.data;"
        "const encodePriceData = async (ticker, priceData, timestamp, isLatest) => {"
        "  const tickerBuffer = Buffer.alloc(15);" "  tickerBuffer.write(ticker);"
        "  const precisionBuffer = Buffer.alloc(1);" "  precisionBuffer.writeUInt8(2, 0);"
        "  const quotes = priceData.quote;" "  let low, med, high;" "  if (isLatest) {"
        "    low = med = high = Math.round(quotes.USD.price * 100);" "  } else {"
        "    [low, med, high] = getQuotes(quotes);" "    low = Math.round(low.USD.price * 100);"
        "    med = Math.round(med.USD.price * 100);" "    high = Math.round(high.USD.price * 100);" "  }"
        "  const variance = getVariance(low, high);" "  const varianceBuffer = Buffer.alloc(2);"
        "  varianceBuffer.writeUInt16LE(variance, 0);" "  const timestampBuffer = Buffer.from("
        '    timestamp.toString(16).padStart(12, "0"),' '    "hex"' "  );"
        '  const priceBuffer = Buffer.from(med.toString(16).padStart(16, "0"), "hex");' "  return Buffer.concat(["
        "    tickerBuffer," "    precisionBuffer," "    varianceBuffer," "    timestampBuffer," "    priceBuffer,"
        "  ]);" "};" "const getQuotes = async (quotes) => {" "  const high = quotes[0];"
        "  const low = quotes[quotes.length - 1];" "  const med = quotes[Math.floor(quotes.length / 2)];"
        "  return [low, med, high];" "};" "const getVariance = (low, high) => {"
        "  return Math.round(((high - low) / low) * 10000);" "};" "const buffers = [];"
        'for (let ticker of tickers.split(",")) {' "  const encodedPriceData = await encodePriceData(" "    ticker,"
        "    data[ticker][0]," "    timestamp," "    isLatest" "  );" "  buffers.push(encodedPriceData);" "}"
        "return Buffer.concat(buffers);";

    // Inline entire file -> Update File for Chain
    string cumulativePnlSource = 'const ethers = await import("npm:ethers@6.10.0");'
        'const { Buffer } = await import("node:buffer");' 'const RPC_URL = "";' 'const MARKET = "0x";'
        'const MARKET_UTILS = "0x";' 'const PRICE_FEED = "0x";' 'const ORACLE = "0x";'
        "const PRECISION_DIVISOR = 10000000000000000000000000000n;" "const MARKET_ABI = [];"
        "const MARKET_UTILS_ABI = [];" "const ORACLE_ABI = [];"
        "// Chainlink Functions compatible Ethers JSON RPC provider class"
        "class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {" "  constructor(url) {" "    super(url);"
        "    this.url = url;" "  }" "  async _send(payload) {" "    let resp = await fetch(this.url, {"
        '      method: "POST",' '      headers: { "Content-Type": "application/json" },'
        "      body: JSON.stringify(payload)," "    });" "    return resp.json();" "  }" "}"
        "const provider = new FunctionsJsonRpcProvider(RPC_URL);"
        "const market = new ethers.Contract(MARKET, MARKET_ABI, provider);" "const marketUtils = new ethers.Contract("
        "  MARKET_UTILS," "  MARKET_UTILS_ABI," "  provider" ");" "const timestamp = Number(args[0]);"
        "const marketId = args[1];" "const tickers = await market.getTickers(marketId);"
        "const getMedianPrice = async (ticker) => {" "  const currentTime = Math.floor(Date.now() / 1000);"
        "  let cmcResponse;" "  let isLatest;"
        "  // If its been < 5 minutes since request, fetch latest prices (lower latency)"
        "  if (currentTime - timestamp < 300) {" "    const cmcRequest = await Functions.makeHttpRequest({"
        "      url: `https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest`,"
        '      headers: { "X-CMC_PRO_API_KEY": secrets.apiKey },' "      params: {" "        symbol: tickers,"
        "      }," "    });" "    cmcResponse = await cmcRequest;" "    isLatest = true;" "  } else {"
        "    const cmcRequest = await Functions.makeHttpRequest({"
        "      url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`,"
        '      headers: { "X-CMC_PRO_API_KEY": secrets.apiKey },' "      params: {" "        symbol: tickers,"
        "        time_end: timestamp," "      }," "    });" "    cmcResponse = await cmcRequest;"
        "    isLatest = false;" "  }" "  if (cmcResponse.status !== 200 || cmcResponse.data.status.error_code !== 0) {"
        '    throw new Error("GET Request to CMC API Failed");' "  }"
        "  const data = cmcResponse.data.data[ticker][0]; // Get the first entry for the ticker"
        "  const quotes = data.quote;" "  let medianPrice;" "  if (isLatest) {"
        "    medianPrice = Math.round(quotes.USD.price * 100);" "  } else {" "    medianPrice = getQuotes(quotes);"
        "  }" "  return medianPrice;" "};" "const getBaseUnit = (ticker) => {" "  const baseUnits = {" "    BTC: 1e8,"
        "    ETH: 1e18," "  };" "  return baseUnits[ticker] || 1e18; // Default to 1e18 if not found" "};"
        "const getQuotes = (quotes) => {" "  return Math.round(quotes[Math.floor(quotes.length / 2)] * 100);" "};"
        "const getRandomOpenInterest = () => {"
        "  return Math.floor(Math.random() * 1000000); // Ensure open interest is always positive" "};"
        "const calculateCumulativePnl = async () => {" "  let cumulativePnl = 0n;" "  for (const ticker of tickers) {"
        "    const medianPrice = await getMedianPrice(ticker);" "    const baseUnit = await getBaseUnit(ticker);"
        "    const pnlLong = await marketUtils.getMarketPnl(" "      marketId," "      MARKET," "      ticker,"
        "      medianPrice," "      baseUnit," "      true" "    );" "    // Convert to 2.dp"
        "    cumulativePnl += pnlLong / PRECISION_DIVISOR;" "    const pnlShort = await marketUtils.getMarketPnl("
        "      marketId," "      MARKET," "      ticker," "      medianPrice," "      baseUnit," "      false" "    );"
        "    // Convert to 2 d.p" "    cumulativePnl += pnlShort / PRECISION_DIVISOR;" "  }" "  return {"
        "    precision: 2," "    timestamp: Math.floor(Date.now() / 1000), // Ensure correct timestamp"
        "    cumulativePnl: cumulativePnl," "  };" "};" "const formatResult = (result) => {"
        "  const buffer = Buffer.alloc(23);" "  // Precision (1 byte)" "  buffer.writeUInt8(result.precision, 0);"
        "  // Timestamp (6 bytes)" "  buffer.writeUIntBE(result.timestamp, 1, 6); // Write timestamp as 6 bytes"
        "  // Cumulative PnL (16 bytes)" "  const pnlBuffer = Buffer.alloc(16);"
        "  let cumulativePnl = BigInt(result.cumulativePnl);" "  if (cumulativePnl < 0) {"
        "    cumulativePnl = BigInt(2) ** BigInt(127) + cumulativePnl; // Convert to twos complement for negative values"
        "  }" "  pnlBuffer.writeBigInt64BE(cumulativePnl, 8); // Store as 128-bit integer"
        "  buffer.set(pnlBuffer, 7); // Set the PnL bytes in the result buffer" '  return buffer.toString("hex");' "};"
        "const result = await calculateCumulativePnl();" "const formattedResult = formatResult(result);"
        'return Buffer.from(formattedResult, "hex");';

    bytes public encryptedSecretsUrls =
        hex"50225c593c3142d7097ed73d01e76e8403a61945b3385dda1f5cc171f9c2f193f102fc1aee84ff9127d4813f63b8bfc2eef78704bc45735473152ee9c5af0b010f09c01fa7fb76693985382a0285315c05fc961266b03038f290373e3c5b011b59c6cbe51aef414f39f14d712f404ef894b57b44c13a809de86eaeea2792dcb06a6fb8fa22352a6ee86a26f2b82e076c6b78d7ccde693bba23d838e538f4d1d79f";

    function run() public {
        vm.startBroadcast();

        IPriceFeed newPriceFeed =
            new PriceFeed(address(marketFactory), weth, link, uniV3Router, uniV3Factory, subId, donId, functionsRouter);

        newPriceFeed.initialize(
            priceUpdateSource,
            cumulativePnlSource,
            185000,
            300_000,
            0.005 ether,
            0.0001 gwei,
            0xb113F5A928BCfF189C998ab20d753a47F9dE5A61,
            sequencerUptimeFeed,
            5 minutes
        );
        newPriceFeed.setEncryptedSecretUrls(encryptedSecretsUrls);
        OwnableRoles(address(newPriceFeed)).grantRoles(address(marketFactory), _ROLE_0);

        marketFactory.updatePriceFeed(newPriceFeed);
        market.updatePriceFeed(newPriceFeed);
        tradeStorage.updatePriceFeed(newPriceFeed);
        tradeEngine.updatePriceFeed(newPriceFeed);
        positionManager.updatePriceFeed(newPriceFeed);
        router.updatePriceFeed(newPriceFeed);
        vm.stopBroadcast();
    }
}
