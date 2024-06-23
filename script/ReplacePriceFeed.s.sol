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
    uint256 private constant _ROLE_3 = 1 << 3;

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

    /// IMPORTANT -> NEED TO REPLACE CHAINLINK FUNCTIONS, AS HARD-CODED ADDRESSES WILL NEED TO
    /// BE SWITCHED TO THE NEW PRICE-FEED ETC.
    function run() public {
        vm.startBroadcast();

        IPriceFeed newPriceFeed =
            new PriceFeed(address(marketFactory), weth, link, uniV3Router, subId, donId, functionsRouter);

        newPriceFeed.initialize(
            priceUpdateSource,
            cumulativePnlSource,
            185000,
            300_000,
            0.005 ether,
            0xb113F5A928BCfF189C998ab20d753a47F9dE5A61,
            sequencerUptimeFeed,
            5 minutes
        );
        newPriceFeed.setEncryptedSecretUrls(encryptedSecretsUrls);
        OwnableRoles(address(newPriceFeed)).grantRoles(address(marketFactory), _ROLE_0);
        OwnableRoles(address(newPriceFeed)).grantRoles(address(router), _ROLE_3);

        marketFactory.updatePriceFeed(newPriceFeed);
        market.updatePriceFeed(newPriceFeed);
        tradeStorage.updatePriceFeed(newPriceFeed);
        tradeEngine.updatePriceFeed(newPriceFeed);
        positionManager.updatePriceFeed(newPriceFeed);
        router.updatePriceFeed(newPriceFeed);
        vm.stopBroadcast();
    }
}
