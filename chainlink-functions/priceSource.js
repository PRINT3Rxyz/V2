const { Buffer } = await import("node:buffer");

const timestamp = Number(args[0]);

const tickers = args.slice(1).join(",");

if (!secrets.API_KEY) {
  throw new Error("Missing COINMARKETCAP_API_KEY");
}

const currentTime = Math.floor(Date.now() / 1000);

let cmcResponse;
let isLatest;

// If its been < 5 minutes since request, fetch latest prices (lower latency)
if (currentTime - timestamp < 300) {
  const cmcRequest = await Functions.makeHttpRequest({
    url: `https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest`,
    headers: { "X-CMC_PRO_API_KEY": secrets.API_KEY },
    params: {
      symbol: tickers,
    },
  });
  cmcResponse = await cmcRequest;
  isLatest = true;
} else {
  const cmcRequest = await Functions.makeHttpRequest({
    url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`,
    headers: { "X-CMC_PRO_API_KEY": secrets.API_KEY },
    params: {
      symbol: tickers,
      time_end: timestamp,
    },
  });
  cmcResponse = await cmcRequest;
  isLatest = false;
}

const cmcRequest = await Functions.makeHttpRequest({
  url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical`,
  headers: {
    "Content-Type": "application/json",
    "X-CMC_PRO_API_KEY": secrets.API_KEY,
  },
  params: {
    symbol: tickers,
    time_end: timestamp,
  },
});

if (cmcResponse.status !== 200) {
  throw new Error("GET Request to CMC API Failed");
}

const data = cmcResponse.data.data;

const encodePriceData = async (ticker, priceData, timestamp, isLatest) => {
  const tickerBuffer = Buffer.alloc(15);
  tickerBuffer.write(ticker);

  const precisionBuffer = Buffer.alloc(1);
  precisionBuffer.writeUInt8(2, 0);

  const quotes = priceData.quote;

  let low, med, high;

  if (isLatest) {
    low = med = high = Math.round(quotes.USD.price * 100);
  } else {
    [low, med, high] = getQuotes(quotes);
    low = Math.round(low.USD.price * 100);
    med = Math.round(med.USD.price * 100);
    high = Math.round(high.USD.price * 100);
  }

  const variance = getVariance(low, high);

  const varianceBuffer = Buffer.alloc(2);
  varianceBuffer.writeUInt16LE(variance, 0);

  const timestampBuffer = Buffer.from(
    timestamp.toString(16).padStart(12, "0"),
    "hex"
  );

  const priceBuffer = Buffer.from(med.toString(16).padStart(16, "0"), "hex");

  return Buffer.concat([
    tickerBuffer,
    precisionBuffer,
    varianceBuffer,
    timestampBuffer,
    priceBuffer,
  ]);
};

const getQuotes = async (quotes) => {
  const high = quotes[0];
  const low = quotes[quotes.length - 1];
  const med = quotes[Math.floor(quotes.length / 2)];

  return [low, med, high];
};

const getVariance = (low, high) => {
  return Math.round(((high - low) / low) * 10000);
};

const buffers = [];

for (let ticker of tickers.split(",")) {
  const encodedPriceData = await encodePriceData(
    ticker,
    data[ticker][0],
    timestamp,
    isLatest
  );
  buffers.push(encodedPriceData);
}

return Buffer.concat(buffers);
