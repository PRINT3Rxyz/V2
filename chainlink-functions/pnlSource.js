const ethers = await import("npm:ethers@6.10.0");
const { Buffer } = await import("node:buffer");

// Replace with Market for Chain
const MARKET = "0xa918067e193D16bA9A5AB36270dDe2869892b276";
// Replace With Market Utils for Chain
const MARKET_UTILS = "0x92c549Fca37b8521533F6238674b768CCd051276";
// Replace With Price Feed for Chain
const PRICE_FEED = "0x5097300604337D2397783b4178214542af551786";

const PRECISION_DIVISOR = 10000000000000000000000000000n;

const MARKET_ABI = [
  {
    "type": "function",
    "name": "getTickers",
    "inputs": [{ "name": "_id", "type": "bytes32", "internalType": "MarketId" }],
    "outputs": [{ "name": "", "type": "string[]", "internalType": "string[]" }],
    "stateMutability": "view"
  }
];
const MARKET_UTILS_ABI = [
  {
    "type": "function",
    "name": "getMarketPnl",
    "inputs": [
      { "name": "_id", "type": "bytes32", "internalType": "MarketId" },
      { "name": "market", "type": "address", "internalType": "contract IMarket" },
      { "name": "_ticker", "type": "string", "internalType": "string" },
      { "name": "_indexPrice", "type": "uint256", "internalType": "uint256" },
      { "name": "_indexBaseUnit", "type": "uint256", "internalType": "uint256" },
      { "name": "_isLong", "type": "bool", "internalType": "bool" }
    ],
    "outputs": [{ "name": "netPnl", "type": "int256", "internalType": "int256" }],
    "stateMutability": "view"
  }
];

class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
  constructor(url) {
    super(url);
    this.url = url;
  }

  async _send(payload) {
    let resp = await fetch(this.url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    return resp.json();
  }
}

const provider = new FunctionsJsonRpcProvider(secrets.RPC_URL);
const market = new ethers.Contract(MARKET, MARKET_ABI, provider);
const marketUtils = new ethers.Contract(MARKET_UTILS, MARKET_UTILS_ABI, provider);

const timestamp = Number(args[0]);
const marketId = args[1];

const tickers = await market.getTickers(marketId);

const getMedianPrice = async (ticker) => {
  const currentTime = Math.floor(Date.now() / 1000);
  let cmcResponse;
  let isLatest;

  if (currentTime - timestamp < 300) {
    const cmcRequest = await Functions.makeHttpRequest({
      url: `https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest`,
      headers: { "X-CMC_PRO_API_KEY": secrets.API_KEY },
      params: { symbol: tickers },
    });
    cmcResponse = await cmcRequest;
    isLatest = true;
  } else {
    const cmcRequest = await Functions.makeHttpRequest({
      url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`,
      headers: { "X-CMC_PRO_API_KEY": secrets.API_KEY },
      params: { symbol: tickers, time_end: timestamp },
    });
    cmcResponse = await cmcRequest;
    isLatest = false;
  }

  if (cmcResponse.status !== 200 || cmcResponse.data.status.error_code !== 0) {
    throw new Error("GET Request to CMC API Failed");
  }

  const data = cmcResponse.data.data[ticker][0];
  const quotes = data.quote;
  let medianPrice;

  if (isLatest) {
    medianPrice = Math.round(quotes.USD.price * 100);
  } else {
    medianPrice = getQuotes(quotes);
  }

  return medianPrice;
};

const getBaseUnit = (ticker) => {
  const baseUnits = { BTC: 1e8, ETH: 1e18 };
  return baseUnits[ticker] || 1e18;
};

const getQuotes = (quotes) => Math.round(quotes[Math.floor(quotes.length / 2)] * 100);

const calculateCumulativePnl = async () => {
  let cumulativePnl = 0n;
  for (const ticker of tickers) {
    const medianPrice = await getMedianPrice(ticker);
    const baseUnit = await getBaseUnit(ticker);

    const pnlLong = await marketUtils.getMarketPnl(marketId, MARKET, ticker, medianPrice, baseUnit, true);
    cumulativePnl += pnlLong / PRECISION_DIVISOR;

    const pnlShort = await marketUtils.getMarketPnl(marketId, MARKET, ticker, medianPrice, baseUnit, false);
    cumulativePnl += pnlShort / PRECISION_DIVISOR;
  }

  return { precision: 2, timestamp: Math.floor(Date.now() / 1000), cumulativePnl: cumulativePnl };
};

const formatResult = (result) => {
  const buffer = Buffer.alloc(23);
  buffer.writeUInt8(result.precision, 0);
  buffer.writeUIntBE(result.timestamp, 1, 6);

  const pnlBuffer = Buffer.alloc(16);
  let cumulativePnl = BigInt(result.cumulativePnl);
  if (cumulativePnl < 0) {
    cumulativePnl = BigInt(2) ** BigInt(127) + cumulativePnl;
  }
  pnlBuffer.writeBigInt64BE(cumulativePnl, 8);
  buffer.set(pnlBuffer, 7);

  return buffer.toString("hex");
};

const result = await calculateCumulativePnl();
const formattedResult = formatResult(result);

const returnValue = Buffer.from(formattedResult, "hex");

return new Uint8Array(returnValue);
