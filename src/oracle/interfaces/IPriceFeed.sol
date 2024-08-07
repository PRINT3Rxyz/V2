// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IMarketFactory} from "../../factory/interfaces/IMarketFactory.sol";
import {MarketId} from "../../types/MarketId.sol";

interface IPriceFeed {
    enum RequestType {
        PRICE_UPDATE,
        CUMULATIVE_PNL
    }

    struct RequestData {
        MarketId marketId;
        address requester;
        uint48 blockTimestamp;
        RequestType requestType;
        string[] args;
    }

    struct SecondaryStrategy {
        // Does the asset have a secondary strategy?
        bool exists;
        // What type of secondary strategy is it?
        FeedType feedType;
        // What is the address of the secondary strategy? (Chainlink etc.)
        address feedAddress;
        // What is the feed ID of the secondary strategy? (Pyth)
        bytes32 feedId;
    }

    enum FeedType {
        CHAINLINK,
        PYTH
    }

    struct Price {
        /**
         * The ticker of the asset. Used to identify the asset.
         * Limited to a maximum of 15 bytes to ensure the struct fits in a 32-byte word.
         */
        bytes15 ticker;
        /**
         * Number of decimal places the price result is accurate to. Let's us expand
         * the price to the correct number of decimal places.
         */
        uint8 precision;
        /**
         * Percentage of variance in the price. Used to determine upper and lower bound prices.
         * Min and max prices are calculated as : med +- (med * variance / 10,000)
         * 10,000 = 100% (100.00). 1 = 0.01% (0.01). 0 = no variance.
         */
        uint16 variance;
        /**
         * Timestamp the price is set for.
         */
        uint48 timestamp;
        /**
         * The median aggregated price (not including outliers) fetched from the price data sources.
         */
        uint64 med;
    }

    struct Pnl {
        uint8 precision;
        uint48 timestamp;
        int128 cumulativePnl;
    }

    // Custom error type
    error PriceFeed_PriceUpdateLength();
    error PriceFeed_AssetSupportFailed();
    error PriceFeed_AssetRemovalFailed();
    error PriceFeed_InvalidMarket();
    error PriceFeed_InvalidRequestType();
    error PriceFeed_PriceRequired(string ticker);
    error PriceFeed_PnlNotSigned();
    error PriceFeed_AlreadyInitialized();
    error PriceFeed_PriceExpired();
    error PriceFeed_FailedToClearRequest();
    error PriceFeed_SwapFailed();
    error PriceFeed_InvalidResponseLength();
    error PriceFeed_ZeroBalance();
    error PriceFeed_InvalidArgsLength();

    // Event to log responses
    event Response(bytes32 indexed requestId, RequestData requestData, bytes response, bytes err);
    event AssetSupported(string ticker, uint8 tokenDecimals);
    event SupportRemoved(string ticker);
    event PriceUpdated(bytes15 indexed ticker, uint48 indexed timestamp, uint64 medianPrice, uint16 variance);
    event PnlUpdated(bytes32 indexed marketId, uint48 indexed timestamp, int128 pnlValue);

    function sequencerUptimeFeed() external view returns (address);
    function initialize(
        string calldata _priceUpdateSource,
        string calldata _cumulativePnlSource,
        uint256 _gasOverhead,
        uint32 _callbackGasLimit,
        uint256 _premiumFee,
        address _sequencerUptimeFeed,
        uint48 _timeToExpiration
    ) external;
    function setEncryptedSecretUrls(bytes calldata _encryptedSecretsUrls) external;
    function getPrices(string memory _ticker, uint48 _timestamp) external view returns (Price memory signedPrices);
    function getCumulativePnl(MarketId marketId, uint48 _timestamp) external view returns (Pnl memory pnl);
    function updateBillingParameters(
        uint64 _subId,
        bytes32 _donId,
        uint256 _gasOverhead,
        uint32 _callbackGasLimit,
        uint256 _premiumFee
    ) external;
    function supportAsset(string memory _ticker, SecondaryStrategy calldata _strategy, uint8 _tokenDecimals) external;
    function unsupportAsset(string memory _ticker) external;
    function requestPriceUpdate(string[] calldata args, address _requester)
        external
        payable
        returns (bytes32 requestId);
    function requestCumulativeMarketPnl(MarketId _id, address _requester) external payable returns (bytes32);
    function getSecondaryStrategy(string memory _ticker) external view returns (SecondaryStrategy memory);
    function priceUpdateRequested(bytes32 _requestId) external view returns (bool);
    function getRequestData(bytes32 _requestId) external view returns (RequestData memory);
    function getRequester(bytes32 _requestId) external view returns (address);
    function callbackGasLimit() external view returns (uint32);
    function gasOverhead() external view returns (uint256);
    function getRequestTimestamp(bytes32 _requestKey) external view returns (uint48);
    function timeToExpiration() external view returns (uint48);
    function isRequestValid(bytes32 _requestKey) external view returns (bool);
    function tokenDecimals(string memory _ticker) external view returns (uint8);
    function pyth() external view returns (address);
    function fullfillmentAttempted(bytes32 _requestKey) external view returns (bool);
}
