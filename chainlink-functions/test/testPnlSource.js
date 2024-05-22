require("@chainlink/env-enc").config();
const axios = require("axios");
const { ethers } = require("ethers");

const testPnlSource = async (args) => {
  const RPC_URL = ""; // Your RPC URL
  const MARKET = "0x"; // Market Address
  const MARKET_UTILS = "0x"; // MarketUtils Address
  const PRICE_FEED = "0x"; // PriceFeed Address
  const ORACLE = "0x"; // Oracle Address

  const PRECISION_DIVISOR = 10000000000000000000000000000n;

  const MARKET_ABI = []; // Market contract ABI
  const MARKET_UTILS_ABI = []; // MarketUtils contract ABI
  const ORACLE_ABI = []; // Oracle contract ABI

  const provider = new ethers.providers.JsonRpcProvider(RPC_URL);

  const market = new ethers.Contract(MARKET, MARKET_ABI, provider);
  const marketUtils = new ethers.Contract(MARKET_UTILS, MARKET_UTILS_ABI, provider);

  const timestamp = Number(args[0]);
  const marketId = args[1];

  const tickers = ['BTC', 'ETH']; // Example tickers

  const getMedianPrice = async (ticker) => {
    const timeStart = timestamp - 1;
    console.log("Time start: ", timeStart);
    const timeEnd = timestamp;
    console.log("Time end: ", timeEnd);

    const cmcRequest = await axios({
      url: `https://pro-api.coinmarketcap.com/v3/cryptocurrency/quotes/historical?symbol=${ticker}&time_start=${timeStart}&time_end=${timeEnd}`,
      headers: { "X-CMC_PRO_API_KEY": process.env.COINMARKETCAP_API_KEY },
      method: "GET",
    });

    const cmcResponse = await cmcRequest;

    if (cmcResponse.status !== 200 || cmcResponse.data.status.error_code !== 0) {
      throw new Error("GET Request to CMC API Failed");
    }

    const data = cmcResponse.data.data[ticker][0]; // Get the first entry for the ticker
    const quotes = data.quotes;


    console.log(`Quotes for ${ticker}:`);
    quotes.forEach((quote, index) => {
      console.log(`Quote ${index + 1}: Open: ${quote.quote.USD.open}, High: ${quote.quote.USD.high}, Low: ${quote.quote.USD.low}, Close: ${quote.quote.USD.close}, Timestamp: ${quote.quote.USD.timestamp}`);

    });

    if (!quotes || quotes.length === 0) {
      throw new Error(`No quotes found for ${ticker}`);
    }

    const validQuotes = quotes.filter((quote) => {
      const usdQuote = quote.quote.USD;
      return usdQuote.open > 0 && usdQuote.high > 0 && usdQuote.low > 0 && usdQuote.close > 0;
    });

    if (validQuotes.length === 0) {
      throw new Error(`No valid quotes found for ${ticker}`);
    }

    const aggregated = validQuotes.reduce(
      (acc, quote) => {
        const usdQuote = quote.quote.USD;
        acc.open += usdQuote.open;
        acc.high += usdQuote.high;
        acc.low += usdQuote.low;
        acc.close += usdQuote.close;
        return acc;
      },
      { open: 0, high: 0, low: 0, close: 0 }
    );

    const medianPrice = (aggregated.open + aggregated.close) / (2 * validQuotes.length);
    return Math.round(medianPrice); // Adjust for one decimal place
  };

  const getBaseUnit = (ticker) => {
    const baseUnits = {
      BTC: 1e8,
      ETH: 1e18,
    };
    return baseUnits[ticker] || 1e18; // Default to 1e18 if not found
  };

  const getRandomOpenInterest = () => {
    return Math.floor(Math.random() * 1000000); // Ensure open interest is always positive
  };

  const calculateCumulativePnl = async () => {
    let cumulativePnl = 0n;

    for (const ticker of tickers) {
      const medianPrice = await getMedianPrice(ticker);
      const baseUnit = getBaseUnit(ticker);

      const openInterestLong = getRandomOpenInterest();
      const openInterestShort = getRandomOpenInterest();

      console.log(`Ticker: ${ticker}`);
      console.log(`Median Price: ${medianPrice / 10}`); // Adjust back to original value
      console.log(`Base Unit: ${baseUnit}`);
      console.log(`Open Interest Long: ${openInterestLong}`);
      console.log(`Open Interest Short: ${openInterestShort}`);

      const pnlLong = BigInt(openInterestLong) * BigInt(medianPrice) / BigInt(baseUnit);
      cumulativePnl += pnlLong;

      const pnlShort = BigInt(openInterestShort) * BigInt(medianPrice) / BigInt(baseUnit);
      cumulativePnl += pnlShort;

      console.log(`PnL Long: ${pnlLong}`);
      console.log(`PnL Short: ${pnlShort}`);
      console.log(`Cumulative PnL: ${cumulativePnl}`);
    }

    // Convert cumulative PnL to 2 decimals of precision
    const scaledCumulativePnl = cumulativePnl; // Direct use without dividing by 100

    return {
      precision: 2,
      timestamp: Math.floor(Date.now() / 1000), // Ensure correct timestamp
      cumulativePnl: scaledCumulativePnl,
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
      cumulativePnl = BigInt(2) ** BigInt(127) + cumulativePnl; // Convert to two's complement for negative values
    }
    pnlBuffer.writeBigInt64BE(cumulativePnl, 8); // Store as 128-bit integer
    buffer.set(pnlBuffer, 7); // Set the PnL bytes in the result buffer

    return buffer.toString("hex");
  };

  const result = await calculateCumulativePnl();
  const formattedResult = formatResult(result);

  return Buffer.from(formattedResult, "hex");
};

const timestamp = Math.floor(Date.now() / 1000);
const MARKET_ID = "0x";
const args = [timestamp.toString(), MARKET_ID];

testPnlSource(args)
  .then((result) => {
    console.log("Result: ", result);
  })
  .catch((err) => console.error(err));
