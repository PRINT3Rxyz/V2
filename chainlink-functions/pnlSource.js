const ethers = await import("npm:ethers@6.10.0");
const { Buffer } = await import("node:buffer");

const RPC_URL = ""; // Your RPC URL
const MARKET = "0x"; // Market Address
const MARKET_UTILS = "0x"; // MarketUtils Address
const PRICE_FEED = "0x"; // PriceFeed Address
const ORACLE = "0x"; // Oracle Address

const PRECISION_DIVISOR = 10000000000000000000000000000n;

const MARKET_ABI = []; // Market contract ABI
const MARKET_UTILS_ABI = []; // MarketUtils contract ABI
const ORACLE_ABI = []; // Oracle contract ABI

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
  const timeStart = timestamp - 1;
  const timeEnd = timestamp;

  const cmcRequest = await Functions.makeHttpRequest({
    url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`,
    headers: {
      "Content-Type": "application/json",
      "X-CMC_PRO_API_KEY": secrets.apiKey,
    },
    params: {
      symbol: tickers,
      time_start: timeStart,
      time_end: timeEnd,
    },
  });

  const cmcResponse = await cmcRequest;

  if (cmcResponse.status !== 200) {
    throw new Error("GET Request to CMC API Failed");
  }

  const data = cmcResponse.data.data;
  const quotes = data[ticker][0].quotes;
  const validQuotes = quotes.filter((quote) => quote.quote && quote.quote.USD);
  const totalQuotes = validQuotes.length;

  if (totalQuotes === 0) {
    return 0;
  }

  const aggregated = validQuotes.reduce(
    (acc, quote) => {
      acc.open += quote.quote.USD.open;
      acc.high += quote.quote.USD.high;
      acc.low += quote.quote.USD.low;
      acc.close += quote.quote.USD.close;
      return acc;
    },
    { open: 0, high: 0, low: 0, close: 0 }
  );

  const medianPrice = (aggregated.open + aggregated.close) / 2;
  return medianPrice;
};

const getBaseUnit = async (ticker) => {
  const oracle = new ethers.Contract(ORACLE, ORACLE_ABI, provider);
  const baseUnit = await oracle.getBaseUnit(PRICE_FEED, ticker);
  return baseUnit;
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

    cumulativePnl += pnlLong;

    const pnlShort = await marketUtils.getMarketPnl(
      marketId,
      MARKET,
      ticker,
      medianPrice,
      baseUnit,
      false
    );

    cumulativePnl += pnlShort;
  }

  // Convert cumulative PnL to 2 decimals of precision
  const scaledCumulativePnl = cumulativePnl / PRECISION_DIVISOR;

  return {
    precision: 2,
    timestamp: timestamp,
    cumulativePnl: scaledCumulativePnl,
  };
};

const formatResult = (result) => {
  const buffer = Buffer.alloc(23);

  // Precision (1 byte)
  buffer.writeUInt8(result.precision, 0);

  // Timestamp (6 bytes)
  buffer.writeBigUInt64BE(BigInt(result.timestamp), 1);

  // Cumulative PnL (16 bytes)
  buffer.writeBigInt64BE(BigInt(result.cumulativePnl), 7);

  return buffer.toString("hex");
};

const result = await calculateCumulativePnl();
const formattedResult = formatResult(result);

return Buffer.from(formattedResult, 'hex');
