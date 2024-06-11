const { Buffer } = await import("node:buffer");

const timestamp = Number(args[0]);
const tickers = args.slice(1).join(",");

if (!secrets.API_KEY) {
  throw new Error("Missing COINMARKETCAP_API_KEY");
}

const currentTime = Math.floor(Date.now() / 1000);

let cmcResponse;
let isLatest;

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

console.log("Request Success? ", cmcResponse);

if (cmcResponse.status !== 200) {
  throw new Error("GET Request to CMC API Failed");
}

const data = cmcResponse.data.data;

const encodePriceData = async (ticker, priceData, timestamp, isLatest) => {
  const tickerHex = Buffer.alloc(15).fill(0);
  tickerHex.write(ticker);
  const tickerHexStr = tickerHex.toString("hex");

  const precisionHex = Buffer.alloc(1);
  precisionHex.writeUInt8(2, 0);
  const precisionHexStr = precisionHex.toString("hex");

  const quotes = isLatest ? priceData.quote : priceData.quotes;

  let low, med, high;

  if (isLatest) {
    low = med = high = Math.round(quotes.USD.price * 100);
  } else {
    [low, med, high] = getQuotes(quotes);
    low = Math.round(low * 100);
    med = Math.round(med * 100);
    high = Math.round(high * 100);
  }

  const variance = getVariance(low, high);
  const varianceHex = Buffer.alloc(2);
  varianceHex.writeUInt16LE(variance, 0);
  const varianceHexStr = varianceHex.toString("hex");

  const timestampHexStr = timestamp.toString(16).padStart(12, "0");

  const priceHexStr = med.toString(16).padStart(16, "0");

  const encodedPriceHex = `${tickerHexStr}${precisionHexStr}${varianceHexStr}${timestampHexStr}${priceHexStr}`;

  return encodedPriceHex;
};

const getQuotes = (quotes) => {
  const prices = quotes.map(quote => quote.quote.USD.price);

  const highPrice = Math.max(...prices);
  const lowPrice = Math.min(...prices);

  const sortedPrices = prices.slice().sort((a, b) => a - b);

  const medianPrice = sortedPrices.length % 2 === 0 
    ? (sortedPrices[sortedPrices.length / 2 - 1] + sortedPrices[sortedPrices.length / 2]) / 2 
    : sortedPrices[Math.floor(sortedPrices.length / 2)];

  return [lowPrice, medianPrice, highPrice];
};

const getVariance = (low, high) => {
  return Math.round(((high - low) / low) * 10000);
};

let finalHexStr = "";

for (let ticker of tickers.split(",")) {
  const encodedPriceData = await encodePriceData(
    ticker,
    data[ticker][0],
    timestamp,
    isLatest
  );
  finalHexStr += encodedPriceData;
}

console.log("Final Hex Str: ", finalHexStr);

const arr = new Uint8Array(finalHexStr.length / 2);

for (let i = 0; i < arr.length; i++) {
  arr[i] = parseInt(finalHexStr.slice(i * 2, i * 2 + 2), 16);
}
console.log("Return Hooray!!! ", arr);

return arr;