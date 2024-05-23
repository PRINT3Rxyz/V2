// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";
import {IPriceFeed} from "../src/oracle/interfaces/IPriceFeed.sol";
import {WETH} from "../src/tokens/WETH.sol";
import {Oracle} from "../src/oracle/Oracle.sol";
import {MockToken} from "../test/mocks/MockToken.sol";
import {IHelperConfig} from "./IHelperConfig.s.sol";

contract HelperConfig is IHelperConfig, Script {
    NetworkConfig private activeNetworkConfig;

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 84532 || block.chainid == 845326957) {
            activeNetworkConfig = getBaseSepoliaConfig();
        } else if (block.chainid == 8453) {
            activeNetworkConfig = getBaseConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getBaseSepoliaConfig() public returns (NetworkConfig memory baseSepoliaConfig) {
        MockUSDC mockUsdc = MockUSDC(0x9881f8b307CC3383500b432a8Ce9597fAfc73A77);
        WETH weth = WETH(0xD8eca5111c93EEf563FAB704F2C6A8DD7A12c77D);
        MockToken link = new MockToken();

        baseSepoliaConfig.weth = address(weth);
        baseSepoliaConfig.usdc = address(mockUsdc);
        baseSepoliaConfig.link = address(link);
        baseSepoliaConfig.uniV3SwapRouter = address(0);
        baseSepoliaConfig.uniV3Factory = address(0);
        baseSepoliaConfig.uniV2Factory = address(0);
        baseSepoliaConfig.chainlinkFeedRegistory = address(0);
        baseSepoliaConfig.pyth = address(0);
        baseSepoliaConfig.subId = 0;
        baseSepoliaConfig.donId = keccak256(abi.encode("DON"));
        baseSepoliaConfig.chainlinkRouter = address(0);
        baseSepoliaConfig.mockFeed = true;
        baseSepoliaConfig.sequencerUptimeFeed = address(0);

        baseSepoliaConfig.priceSource = 'const { Buffer } = await import("node:buffer");'
            "const timestamp = Number(args[0]);" 'const tickers = args.slice(1).join(",");' "if (!secrets.apiKey) {"
            'throw new Error("Missing COINMARKETCAP_API_KEY");' "}" "const currentTime = Math.floor(Date.now() / 1000);"
            "let cmcResponse;" "let isLatest;"
            "// If its been < 5 minutes since request, fetch latest prices (lower latency)"
            "if (currentTime - timestamp < 300) {" "const cmcRequest = await Functions.makeHttpRequest({"
            "url: `https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest`,"
            'headers: { "X-CMC_PRO_API_KEY": secrets.apiKey },' "params: {" "symbol: tickers," "}," "});"
            "cmcResponse = await cmcRequest;" "isLatest = true;" "} else {"
            "const cmcRequest = await Functions.makeHttpRequest({"
            "url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`,"
            'headers: { "X-CMC_PRO_API_KEY": secrets.apiKey },' "params: {" "symbol: tickers," "time_end: timestamp,"
            "}," "});" "cmcResponse = await cmcRequest;" "isLatest = false;" "}"
            "const cmcRequest = await Functions.makeHttpRequest({"
            "url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`," "headers: {"
            '"Content-Type": "application/json",' '"X-CMC_PRO_API_KEY": secrets.apiKey,' "}," "params: {"
            "symbol: tickers," "time_end: timestamp," "}," "});" "if (cmcResponse.status !== 200) {"
            'throw new Error("GET Request to CMC API Failed");' "}" "const data = cmcResponse.data.data;"
            "const encodePriceData = async (ticker, priceData, timestamp, isLatest) => {"
            "const tickerBuffer = Buffer.alloc(15);" "tickerBuffer.write(ticker);"
            "const precisionBuffer = Buffer.alloc(1);" "precisionBuffer.writeUInt8(2, 0);"
            "const quotes = priceData.quote;" "let low, med, high;" "if (isLatest) {"
            "low = med = high = Math.round(quotes.USD.price * 100);" "} else {" "[low, med, high] = getQuotes(quotes);"
            "low = Math.round(low.USD.price * 100);" "med = Math.round(med.USD.price * 100);"
            "high = Math.round(high.USD.price * 100);" "}" "const variance = getVariance(low, high);"
            "const varianceBuffer = Buffer.alloc(2);" "varianceBuffer.writeUInt16LE(variance, 0);"
            "const timestampBuffer = Buffer.from(" 'timestamp.toString(16).padStart(12, "0"),' '"hex"' ");"
            'const priceBuffer = Buffer.from(med.toString(16).padStart(16, "0"), "hex");' "return Buffer.concat(["
            "tickerBuffer," "precisionBuffer," "varianceBuffer," "timestampBuffer," "priceBuffer," "]);" "};"
            "const getQuotes = async (quotes) => {" "const high = quotes[0];" "const low = quotes[quotes.length - 1];"
            "const med = quotes[Math.floor(quotes.length / 2)];" "return [low, med, high];" "};"
            "const getVariance = (low, high) => {" "return Math.round(((high - low) / low) * 10000);" "};"
            "const buffers = [];" 'for (let ticker of tickers.split(",")) {'
            "const encodedPriceData = await encodePriceData(" "ticker," "data[ticker][0]," "timestamp," "isLatest" ");"
            "buffers.push(encodedPriceData);" "};" "return Buffer.concat(buffers);";

        baseSepoliaConfig.pnlSource = '    const ethers = await import("npm:ethers@6.10.0");'
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
            "const market = new ethers.Contract(MARKET, MARKET_ABI, provider);"
            "const marketUtils = new ethers.Contract(" "  MARKET_UTILS," "  MARKET_UTILS_ABI," "  provider" ");"
            "const timestamp = Number(args[0]);" "const marketId = args[1];"
            "const tickers = await market.getTickers(marketId);" "const getMedianPrice = async (ticker) => {"
            "  const currentTime = Math.floor(Date.now() / 1000);" "  let cmcResponse;" "  let isLatest;"
            "  // If its been < 5 minutes since request, fetch latest prices (lower latency)"
            "  if (currentTime - timestamp < 300) {" "    const cmcRequest = await Functions.makeHttpRequest({"
            "      url: `https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest`,"
            '      headers: { "X-CMC_PRO_API_KEY": secrets.apiKey },' "      params: {" "        symbol: tickers,"
            "      }," "    });" "    cmcResponse = await cmcRequest;" "    isLatest = true;" "  } else {"
            "    const cmcRequest = await Functions.makeHttpRequest({"
            "      url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`,"
            '      headers: { "X-CMC_PRO_API_KEY": secrets.apiKey },' "      params: {" "        symbol: tickers,"
            "        time_end: timestamp," "      }," "    });" "    cmcResponse = await cmcRequest;"
            "    isLatest = false;" "  }"
            "  if (cmcResponse.status !== 200 || cmcResponse.data.status.error_code !== 0) {"
            '    throw new Error("GET Request to CMC API Failed");' "  }"
            "  const data = cmcResponse.data.data[ticker][0]; // Get the first entry for the ticker"
            "  const quotes = data.quote;" "  let medianPrice;" "  if (isLatest) {"
            "    medianPrice = Math.round(quotes.USD.price * 100);" "  } else {" "    medianPrice = getQuotes(quotes);"
            "  }" "  return medianPrice;" "};" "const getBaseUnit = (ticker) => {" "  const baseUnits = {"
            "    BTC: 1e8," "    ETH: 1e18," "  };"
            "  return baseUnits[ticker] || 1e18; // Default to 1e18 if not found" "};" "const getQuotes = (quotes) => {"
            "  return Math.round(quotes[Math.floor(quotes.length / 2)] * 100);" "};"
            "const getRandomOpenInterest = () => {"
            "  return Math.floor(Math.random() * 1000000); // Ensure open interest is always positive" "};"
            "const calculateCumulativePnl = async () => {" "  let cumulativePnl = 0n;"
            "  for (const ticker of tickers) {" "    const medianPrice = await getMedianPrice(ticker);"
            "    const baseUnit = await getBaseUnit(ticker);" "    const pnlLong = await marketUtils.getMarketPnl("
            "      marketId," "      MARKET," "      ticker," "      medianPrice," "      baseUnit," "      true"
            "    );" "    // Convert to 2.dp" "    cumulativePnl += pnlLong / PRECISION_DIVISOR;"
            "    const pnlShort = await marketUtils.getMarketPnl(" "      marketId," "      MARKET," "      ticker,"
            "      medianPrice," "      baseUnit," "      false" "    );" "    // Convert to 2 d.p"
            "    cumulativePnl += pnlShort / PRECISION_DIVISOR;" "  }" "  return {" "    precision: 2,"
            "    timestamp: Math.floor(Date.now() / 1000), // Ensure correct timestamp"
            "    cumulativePnl: cumulativePnl," "  };" "};" "const formatResult = (result) => {"
            "  const buffer = Buffer.alloc(23);" "  // Precision (1 byte)" "  buffer.writeUInt8(result.precision, 0);"
            "  // Timestamp (6 bytes)" "  buffer.writeUIntBE(result.timestamp, 1, 6); // Write timestamp as 6 bytes"
            "  // Cumulative PnL (16 bytes)" "  const pnlBuffer = Buffer.alloc(16);"
            "  let cumulativePnl = BigInt(result.cumulativePnl);" "  if (cumulativePnl < 0) {"
            "    cumulativePnl = BigInt(2) ** BigInt(127) + cumulativePnl; // Convert to twos complement for negative values"
            "  }" "  pnlBuffer.writeBigInt64BE(cumulativePnl, 8); // Store as 128-bit integer"
            "  buffer.set(pnlBuffer, 7); // Set the PnL bytes in the result buffer" '  return buffer.toString("hex");'
            "};" "const result = await calculateCumulativePnl();" "const formattedResult = formatResult(result);"
            'return Buffer.from(formattedResult, "hex");';

        activeNetworkConfig = baseSepoliaConfig;
    }

    // function getSepoliaConfig() public returns (NetworkConfig memory sepoliaConfig) {
    //     // Need to configurate Price Feed for Sepolia and return
    //     MockUSDC mockUsdc = new MockUSDC();
    //     WETH weth = new WETH();

    //     sepoliaConfig.weth = address(weth);
    //     sepoliaConfig.usdc = address(mockUsdc);
    //     sepoliaConfig.link = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    //     sepoliaConfig.uniV3SwapRouter = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
    //     sepoliaConfig.uniV3Factory = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;
    //     sepoliaConfig.subId = 1; // To fill out
    //     sepoliaConfig.donId = keccak256(abi.encode("DON")); // To fill out
    //     sepoliaConfig.chainlinkRouter = 0x7AFe30cB3E53dba6801aa0EA647A0EcEA7cBe18d; // To fill out
    //     sepoliaConfig.mockFeed = false;
    //     sepoliaConfig.sequencerUptimeFeed = address(0);

    //     activeNetworkConfig = sepoliaConfig;
    // }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getBaseConfig() public view returns (NetworkConfig memory baseConfig) {
        // Need to configurate Price Feed for Base and return
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory anvilConfig) {
        MockUSDC mockUsdc = new MockUSDC();
        WETH weth = new WETH();
        MockToken link = new MockToken();

        anvilConfig.weth = address(weth);
        anvilConfig.usdc = address(mockUsdc);
        anvilConfig.link = address(link);
        anvilConfig.uniV3SwapRouter = address(0);
        anvilConfig.uniV3Factory = address(0);
        anvilConfig.uniV2Factory = address(0);
        anvilConfig.chainlinkFeedRegistory = address(0);
        anvilConfig.pyth = address(0);
        anvilConfig.subId = 0;
        anvilConfig.donId = keccak256(abi.encode("DON"));
        anvilConfig.chainlinkRouter = address(0);
        anvilConfig.mockFeed = true;
        anvilConfig.sequencerUptimeFeed = address(0);

        activeNetworkConfig = anvilConfig;
    }
}
