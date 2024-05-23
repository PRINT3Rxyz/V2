const ethers = await import("npm:ethers@6.10.0");
const { Buffer } = await import("node:buffer");

const RPC_URL = "";
const MARKET = "0x";
const MARKET_UTILS = "0x";
const PRICE_FEED = "0x";
const ORACLE = "0x";

const PRECISION_DIVISOR = 10000000000000000000000000000n;

const MARKET_ABI = [];
const MARKET_UTILS_ABI = [];
const ORACLE_ABI = [];

// Chainlink Functions compatible Ethers JSON RPC provider class
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

const provider = new FunctionsJsonRpcProvider(RPC_URL);

const market = new ethers.Contract(MARKET, MARKET_ABI, provider);
const marketUtils = new ethers.Contract(
  MARKET_UTILS,
  MARKET_UTILS_ABI,
  provider
);

const timestamp = Number(args[0]);
const marketId = args[1];

const tickers = await market.getTickers(marketId);

const getMedianPrice = async (ticker) => {
  const currentTime = Math.floor(Date.now() / 1000);

  let cmcResponse;
  let isLatest;

  // If its been < 5 minutes since request, fetch latest prices (lower latency)
  if (currentTime - timestamp < 300) {
    const cmcRequest = await Functions.makeHttpRequest({
      url: `https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest`,
      headers: { "X-CMC_PRO_API_KEY": secrets.apiKey },
      params: {
        symbol: tickers,
      },
    });
    cmcResponse = await cmcRequest;
    isLatest = true;
  } else {
    const cmcRequest = await Functions.makeHttpRequest({
      url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`,
      headers: { "X-CMC_PRO_API_KEY": secrets.apiKey },
      params: {
        symbol: tickers,
        time_end: timestamp,
      },
    });
    cmcResponse = await cmcRequest;
    isLatest = false;
  }

  if (cmcResponse.status !== 200 || cmcResponse.data.status.error_code !== 0) {
    throw new Error("GET Request to CMC API Failed");
  }

  const data = cmcResponse.data.data[ticker][0]; // Get the first entry for the ticker
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
  const baseUnits = {
    BTC: 1e8,
    ETH: 1e18,
  };
  return baseUnits[ticker] || 1e18; // Default to 1e18 if not found
};

const getQuotes = (quotes) => {
  return Math.round(quotes[Math.floor(quotes.length / 2)] * 100);
};

const getRandomOpenInterest = () => {
  return Math.floor(Math.random() * 1000000); // Ensure open interest is always positive
};

const calculateCumulativePnl = async () => {
  let cumulativePnl = 0n;

  for (const ticker of tickers) {
    const medianPrice = await getMedianPrice(ticker);
    const baseUnit = await getBaseUnit(ticker);

    const pnlLong = await marketUtils.getMarketPnl(
      marketId,
      MARKET,
      ticker,
      medianPrice,
      baseUnit,
      true
    );

    // Convert to 2.dp
    cumulativePnl += pnlLong / PRECISION_DIVISOR;

    const pnlShort = await marketUtils.getMarketPnl(
      marketId,
      MARKET,
      ticker,
      medianPrice,
      baseUnit,
      false
    );

    // Convert to 2 d.p
    cumulativePnl += pnlShort / PRECISION_DIVISOR;
  }

  return {
    precision: 2,
    timestamp: Math.floor(Date.now() / 1000), // Ensure correct timestamp
    cumulativePnl: cumulativePnl,
  };
};

const formatResult = (result) => {
  const buffer = Buffer.alloc(23);

  // Precision (1 byte)
  buffer.writeUInt8(result.precision, 0);

  // Timestamp (6 bytes)
  buffer.writeUIntBE(result.timestamp, 1, 6); // Write timestamp as 6 bytes

  // Cumulative PnL (16 bytes)
  const pnlBuffer = Buffer.alloc(16);
  let cumulativePnl = BigInt(result.cumulativePnl);
  if (cumulativePnl < 0) {
    cumulativePnl = BigInt(2) ** BigInt(127) + cumulativePnl; // Convert to twos complement for negative values
  }
  pnlBuffer.writeBigInt64BE(cumulativePnl, 8); // Store as 128-bit integer
  buffer.set(pnlBuffer, 7); // Set the PnL bytes in the result buffer

  return buffer.toString("hex");
};

const result = await calculateCumulativePnl();
const formattedResult = formatResult(result);

return Buffer.from(formattedResult, "hex");