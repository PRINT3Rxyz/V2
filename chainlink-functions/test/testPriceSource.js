require("@chainlink/env-enc").config();
const axios = require("axios");

const testPriceSource = async (args) => {
  const timestamp = Number(args[0]);
  const tickers = args.slice(1).join(",");

  if (!process.env.COINMARKETCAP_API_KEY) {
    throw new Error(
      "COINMARKETCAP_API_KEY environment variable not set for CoinMarketCap API. Get a free key from https://coinmarketcap.com/api/"
    );
  }

  const currentTime = Math.floor(Date.now() / 1000);

  let cmcResponse;
  let isLatest;

  // If it's been < 5 minutes since request, fetch latest prices (lower latency)
  if (currentTime - timestamp < 300) {
      const cmcRequest = await axios({
        url: `https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest?symbol=${tickers}`,
        headers: { "X-CMC_PRO_API_KEY": process.env.COINMARKETCAP_API_KEY },
        method: "GET",
      });
      cmcResponse = await cmcRequest;
      isLatest = true;
  } else {
      const cmcRequest = await axios({
        url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical?symbol=${tickers}&time_end=${timestamp}`,
        headers: { "X-CMC_PRO_API_KEY": process.env.COINMARKETCAP_API_KEY },
        method: "GET",
      });
      cmcResponse = await cmcRequest;
      isLatest = false;
  }

  if (cmcResponse.error) {
    throw new Error(`Request Failed with status ${cmcResponse.error}`);
  }

  const data = cmcResponse.data.data;
  console.log("Data: ", data);

  const buffers = [];

  for (let ticker of tickers.split(',')) {
    console.log("Ticker: ", ticker);
    console.log("Data: ", data[ticker]);
    const encodedPriceData = encodePriceData(ticker, data[ticker][0], timestamp, isLatest);
    buffers.push(encodedPriceData);
  }

  return Buffer.concat(buffers);
};

const encodePriceData = (ticker, priceData, timestamp, isLatest) => {
    const tickerBuffer = Buffer.alloc(15);
    tickerBuffer.write(ticker);
  
    const precisionBuffer = Buffer.alloc(1);
    precisionBuffer.writeUInt8(2, 0);
  
    const quotes = priceData.quote;
  
    console.log("Quotes: ", quotes);
  
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
  
    const timestampBuffer = Buffer.from(timestamp.toString(16).padStart(12, '0'), 'hex');

    console.log("Timestamp Buffer: ", timestampBuffer);
    console.log("Timestamp: ", timestamp);
  
    const priceBuffer = Buffer.from(med.toString(16).padStart(16, '0'), 'hex');

    console.log("Price Buffer: ", priceBuffer);
  
    return Buffer.concat([tickerBuffer, precisionBuffer, varianceBuffer, timestampBuffer, priceBuffer]);
  };
  
  const getQuotes = (quotes) => {
    const high = quotes[0];
    const low = quotes[quotes.length - 1];
    const med = quotes[Math.floor(quotes.length / 2)];
  
    return [low, med, high];
  };
  
  const getVariance = (low, high) => {
    return Math.round(((high - low) / low) * 10000);
  };
  
  const timestamp = Math.floor(Date.now() / 1000);
  const args = [timestamp.toString(), "BTC", "ETH", "USDC"];
  
  testPriceSource(args).then((result) => {
    console.log("Concatenated Buffer: ", result);
    const finalResult = new Uint8Array(result);
    console.log("Final Result: ", finalResult);
  }).catch((error) => {
    console.error("Error: ", error);
  });