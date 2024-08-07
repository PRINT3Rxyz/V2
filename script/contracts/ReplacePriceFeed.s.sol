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
import {MarketIdLibrary} from "src/types/MarketId.sol";

contract ReplacePriceFeed is Script {
    MarketFactory marketFactory = MarketFactory(0x516dC01DD2D76E3C3576621b28Eba05c7df61335);
    Market market = Market(0xF9271C5C66F1C29FB48Bcd6bba5350df80160887);
    TradeStorage tradeStorage = TradeStorage(0x9C4C333B6A43bCfb12a7d8fc76Ad8EF957C469Ec);
    TradeEngine tradeEngine = TradeEngine(0x3acB3747667268047f668d3dC0EfDdE9D1bE393E);
    PositionManager positionManager = PositionManager(payable(0xF7bC9A70A048AB4111D39f6893c1fE4fB4d5B51D));
    Router router = Router(payable(0x4d653708754BEe9eC3546A93729018C6Ef574d75));

    // Fill old pricefeed here
    PriceFeed oldPriceFeed = PriceFeed(address(0));

    address functionsRouter = 0xf9B8fc078197181C841c296C876945aaa425B278;
    address weth = 0x4200000000000000000000000000000000000006;
    address link = 0xE4aB69C077896252FAFBD49EFD26B5D171A32410;
    address pyth = 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729;
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
        'const { Buffer } = await import("node:buffer");' 'const MARKET = "0x883BA4C0fe91f023CC7e67C20955cEDba20F2298";'
        'const MARKET_UTILS = "0x64664E89D9aF9B4983bD7dF47E339756612A08c9";'
        "const PRECISION_DIVISOR = 10000000000000000000000000000n;" "const MARKET_ABI = [" "  {" '    type: "function",'
        '    name: "getTicker",' '    inputs: [{ name: "_id", type: "bytes32", internalType: "MarketId" }],'
        '    outputs: [{ name: "", type: "string", internalType: "string" }],' '    stateMutability: "view",' "  },"
        "];" "const MARKET_UTILS_ABI = [" "  {" '    type: "function",' '    name: "getMarketPnl",' "    inputs: ["
        '      { name: "_id", type: "bytes32", internalType: "MarketId" },'
        '      { name: "_market", type: "address", internalType: "address" },'
        '      { name: "_indexPrice", type: "uint256", internalType: "uint256" },'
        '      { name: "_isLong", type: "bool", internalType: "bool" }' "    ]," "    outputs: ["
        '      { name: "netPnl", type: "int256", internalType: "int256" }' "    ]," '    stateMutability: "view"' "  },"
        "];" "class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {" "  constructor(url) {" "    super(url);"
        "    this.url = url;" "  }" "  async _send(payload) {" "    let resp = await fetch(this.url, {"
        '      method: "POST",' '      headers: { "Content-Type": "application/json" },'
        "      body: JSON.stringify(payload)," "    });" "    return resp.json();" "  }" "}"
        "const provider = new FunctionsJsonRpcProvider(secrets.RPC_URL);"
        "const market = new ethers.Contract(MARKET, MARKET_ABI, provider);" "const marketUtils = new ethers.Contract("
        "  MARKET_UTILS," "  MARKET_UTILS_ABI," "  provider" ");" "const timestamp = Number(args[0]);"
        "const marketId = args[1];" "const ticker = await market.getTicker(marketId);"
        "const getMedianPrice = async (ticker) => {" "  const currentTime = Math.floor(Date.now() / 1000);"
        "  let cmcResponse;" "  let isLatest;" "  if (currentTime - timestamp < 300) {"
        "    const cmcRequest = await Functions.makeHttpRequest({"
        "      url: `https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest`,"
        '      headers: { "X-CMC_PRO_API_KEY": secrets.API_KEY },' "      params: { symbol: ticker }," "    });"
        "    cmcResponse = await cmcRequest;" "    isLatest = true;" "  } else {"
        "    const cmcRequest = await Functions.makeHttpRequest({"
        "      url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`,"
        '      headers: { "X-CMC_PRO_API_KEY": secrets.API_KEY },'
        "      params: { symbol: ticker, time_end: timestamp }," "    });" "    cmcResponse = await cmcRequest;"
        "    isLatest = false;" "  }" "  if (cmcResponse.status !== 200 || cmcResponse.data.status.error_code !== 0) {"
        '    throw new Error("GET Request to CMC API Failed");' "  }" "  const data = cmcResponse.data.data[ticker][0];"
        "  const quotes = isLatest ? data.quote : data.quotes;" "  let medianPrice;" "  if (isLatest) {"
        "    medianPrice =" "      BigInt(Math.round(quotes.USD.price * 100)) *" "      10000000000000000000000000000n;"
        "  } else {" "    medianPrice =" "      BigInt(Math.round(getQuote(quotes) * 100)) *"
        "      10000000000000000000000000000n;" "  }" "  return medianPrice;" "};" "const getQuote = (quotes) => {"
        "  const prices = quotes.map((quote) => quote.quote.USD.price);"
        "  const sortedPrices = prices.slice().sort((a, b) => a - b);" "  const medianPrice ="
        "    sortedPrices.length % 2 === 0" "      ? (sortedPrices[sortedPrices.length / 2 - 1] +"
        "          sortedPrices[sortedPrices.length / 2]) /" "        2"
        "      : sortedPrices[Math.floor(sortedPrices.length / 2)];" "  return medianPrice;" "};"
        "const calculateCumulativePnl = async () => {" "  let cumulativePnl = 0n;"
        "  const medianPrice = await getMedianPrice(ticker);" "  const pnlLong = await marketUtils.getMarketPnl("
        "    marketId," "    MARKET," "    medianPrice," "    true" "  );"
        "  cumulativePnl += pnlLong / PRECISION_DIVISOR;" "  const pnlShort = await marketUtils.getMarketPnl("
        "    marketId," "    MARKET," "    medianPrice," "    false" "  );"
        "  cumulativePnl += pnlShort / PRECISION_DIVISOR;" "  " "  return {" "    precision: 2,"
        "    timestamp: timestamp," "    cumulativePnl: cumulativePnl," "  };" "};" "const formatResult = (result) => {"
        "  const buffer = Buffer.alloc(23);" "  buffer.writeUInt8(result.precision, 0);"
        "  buffer.writeUIntBE(result.timestamp, 1, 6);" "  const pnlBuffer = Buffer.alloc(16);"
        "  let cumulativePnl = BigInt(result.cumulativePnl);" "  if (cumulativePnl < 0) {"
        "    cumulativePnl = BigInt(2) ** BigInt(127) + cumulativePnl;" "  }"
        "  pnlBuffer.writeBigInt64BE(cumulativePnl, 8);" "  buffer.set(pnlBuffer, 7);"
        '  return buffer.toString("hex");' "};" "const result = await calculateCumulativePnl();"
        'console.log("Result: ", result);' "const formattedResult = formatResult(result);"
        "console.log(`Formatted result is ${formattedResult}`);"
        "const arr = new Uint8Array(formattedResult.length / 2);" "for (let i = 0; i < arr.length; i++) {"
        "  arr[i] = parseInt(formattedResult.slice(i * 2, i * 2 + 2), 16);" "}" 'console.log("Arr: ", arr);'
        "return arr;";

    bytes public encryptedSecretsUrls =
        hex"50225c593c3142d7097ed73d01e76e8403a61945b3385dda1f5cc171f9c2f193f102fc1aee84ff9127d4813f63b8bfc2eef78704bc45735473152ee9c5af0b010f09c01fa7fb76693985382a0285315c05fc961266b03038f290373e3c5b011b59c6cbe51aef414f39f14d712f404ef894b57b44c13a809de86eaeea2792dcb06a6fb8fa22352a6ee86a26f2b82e076c6b78d7ccde693bba23d838e538f4d1d79f";

    /// IMPORTANT -> NEED TO REPLACE CHAINLINK FUNCTIONS, AS HARD-CODED ADDRESSES WILL NEED TO
    /// BE SWITCHED TO THE NEW PRICE-FEED ETC.
    // IMPORTANT -> NEED TO SUPPORT ALL ASSETS SUPPORTED BY THE OLD FEED OR STATE WILL BE INCONSISTENT
    function run() public {
        vm.startBroadcast();

        IPriceFeed newPriceFeed = new PriceFeed(address(marketFactory), weth, link, pyth, subId, donId, functionsRouter);

        newPriceFeed.initialize(
            priceUpdateSource, cumulativePnlSource, 185000, 300_000, 0.005 ether, sequencerUptimeFeed, 5 minutes
        );

        newPriceFeed.setEncryptedSecretUrls(encryptedSecretsUrls);

        bytes32[] memory marketIds = marketFactory.getMarketIds();

        // Temporarily grant MarketFactory role to deployer to replace all assets previously supported
        OwnableRoles(address(newPriceFeed)).grantRoles(msg.sender, _ROLE_0);
        for (uint256 i = 0; i < marketIds.length;) {
            string memory ticker = market.getTicker(MarketIdLibrary.toId(marketIds[i]));
            IPriceFeed.SecondaryStrategy memory secondaryStrategy = oldPriceFeed.getSecondaryStrategy(ticker);
            uint8 decimals = oldPriceFeed.tokenDecimals(ticker);
            newPriceFeed.supportAsset(ticker, secondaryStrategy, decimals);
            unchecked {
                ++i;
            }
        }
        OwnableRoles(address(newPriceFeed)).revokeRoles(msg.sender, _ROLE_0);

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
