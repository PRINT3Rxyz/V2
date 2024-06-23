// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IMarket} from "../../../src/markets/interfaces/IMarket.sol";
import {EnumerableSetLib} from "../../src/libraries/EnumerableSetLib.sol";
import {EnumerableMap} from "../../../src/libraries/EnumerableMap.sol";
import {IMarketFactory} from "../../../src/factory/interfaces/IMarketFactory.sol";
import {IPriceFeed} from "../../../src/oracle/interfaces/IPriceFeed.sol";
import {ISwapRouter} from "../../src/oracle/interfaces/ISwapRouter.sol";
import {IWETH} from "../../src/tokens/interfaces/IWETH.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {Oracle} from "../../src/oracle/Oracle.sol";
import {LibString} from "../../src/libraries/LibString.sol";
import {MarketId, MarketIdLibrary} from "src/types/MarketId.sol";

contract MockPriceFeed is FunctionsClient, IPriceFeed {
    using FunctionsRequest for FunctionsRequest.Request;
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using EnumerableMap for EnumerableMap.PriceMap;
    using LibString for bytes15;
    using MarketIdLibrary for bytes32;

    uint256 public constant PRICE_DECIMALS = 30;
    // Length of 1 Bytes32 Word
    uint8 private constant WORD = 32;
    uint8 private constant PNL_BYTES = 23;
    uint8 private constant MIN_EXPIRATION_TIME = 2 minutes;
    uint40 private constant MSB1 = 0x8000000000;
    uint64 private constant LINK_BASE_UNIT = 1e18;
    uint16 private constant MAX_DATA_LENGTH = 3296;
    // Uniswap V3 Router address on Network
    address public immutable UNISWAP_V3_ROUTER;
    // WETH address on Network
    address public immutable WETH;
    // LINK address on Network
    address public immutable LINK;

    IMarketFactory public marketFactory;
    IMarket market;

    // Don IDs: https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 private donId;
    address public sequencerUptimeFeed;
    uint64 subscriptionId;
    uint8 maxRetries;
    bool private isInitialized;

    uint8 donHostedSecretsSlotID;
    uint64 donHostedSecretsVersion;
    bytes encryptedSecretsUrls;
    // JavaScript source code
    // Hard code the javascript source code here for each request's execution function
    string priceUpdateSource;
    string cumulativePnlSource;

    //Callback gas limit
    uint256 public gasOverhead;
    uint256 public premiumFee;
    address public nativeLinkPriceFeed;
    uint32 public callbackGasLimit;
    uint48 public timeToExpiration;

    // State variable to store the returned character information
    mapping(string ticker => mapping(uint48 blockTimestamp => Price priceResponse)) private prices;
    mapping(MarketId marketId => mapping(uint48 blockTimestamp => Pnl cumulativePnl)) public cumulativePnl;
    // store who requested the data and what type of data was requested
    // only the keeper who requested can fill the order for non market orders
    // all pricing should be cleared once the request is filled
    // data should be tied only to the request as its specific to the request
    mapping(string ticker => SecondaryStrategy) private strategies;
    mapping(string ticker => uint8) public tokenDecimals;

    // Dictionary to enable clearing of the RequestKey
    // Bi-directional to handle the case of invalidated requests
    mapping(bytes32 requestId => bytes32 requestKey) private idToKey;
    mapping(bytes32 requestKey => bytes32 requestId) private keyToId;
    /**
     * Used to count the number of failed price / pnl retrievals. If > MAX, the request is
     * invalidated and removed from storage.
     */
    mapping(bytes32 requestKey => uint256 retries) numberOfRetries;
    EnumerableMap.PriceMap private requestData;
    EnumerableSetLib.Bytes32Set private assetIds;
    EnumerableSetLib.Bytes32Set private requestKeys;

    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor(
        address _marketFactory,
        address _weth,
        address _link,
        address _uniV3Router,
        uint64 _subId,
        bytes32 _donId,
        address _router
    ) FunctionsClient(_router) {
        marketFactory = IMarketFactory(_marketFactory);
        WETH = _weth;
        LINK = _link;
        UNISWAP_V3_ROUTER = _uniV3Router;
        subscriptionId = _subId;
        donId = _donId;
    }

    function initialize(
        string calldata _priceUpdateSource,
        string calldata _cumulativePnlSource,
        uint256 _gasOverhead,
        uint32 _callbackGasLimit,
        uint256 _premiumFee,
        address _nativeLinkPriceFeed,
        address _sequencerUptimeFeed,
        uint48 _timeToExpiration
    ) external {
        if (isInitialized) revert PriceFeed_AlreadyInitialized();
        priceUpdateSource = _priceUpdateSource;
        cumulativePnlSource = _cumulativePnlSource;
        gasOverhead = _gasOverhead;
        callbackGasLimit = _callbackGasLimit;
        premiumFee = _premiumFee;
        nativeLinkPriceFeed = _nativeLinkPriceFeed;
        sequencerUptimeFeed = _sequencerUptimeFeed;
        timeToExpiration = _timeToExpiration;
        isInitialized = true;
    }

    function setEncryptedSecretUrls(bytes calldata _encryptedSecretsUrls) external {
        encryptedSecretsUrls = _encryptedSecretsUrls;
    }

    function updateBillingParameters(
        uint64 _subId,
        bytes32 _donId,
        uint256 _gasOverhead,
        uint32 _callbackGasLimit,
        uint256 _premiumFee,
        address _nativeLinkPriceFeed
    ) external {
        subscriptionId = _subId;
        donId = _donId;
        gasOverhead = _gasOverhead;
        callbackGasLimit = _callbackGasLimit;
        premiumFee = _premiumFee;
        nativeLinkPriceFeed = _nativeLinkPriceFeed;
    }

    function setJavascriptSourceCode(string memory _priceUpdateSource, string memory _cumulativePnlSource) external {
        priceUpdateSource = _priceUpdateSource;
        cumulativePnlSource = _cumulativePnlSource;
    }

    function supportAsset(string memory _ticker, SecondaryStrategy calldata _strategy, uint8 _tokenDecimals) external {
        bytes32 assetId = keccak256(abi.encode(_ticker));
        if (assetIds.contains(assetId)) return; // Return if already supported
        bool success = assetIds.add(assetId);
        if (!success) revert PriceFeed_AssetSupportFailed();
        strategies[_ticker] = _strategy;
        tokenDecimals[_ticker] = _tokenDecimals;
        emit AssetSupported(_ticker, _tokenDecimals);
    }

    function unsupportAsset(string memory _ticker) external {
        bytes32 assetId = keccak256(abi.encode(_ticker));
        if (!assetIds.contains(assetId)) return; // Return if not supported
        bool success = assetIds.remove(assetId);
        if (!success) revert PriceFeed_AssetRemovalFailed();
        delete strategies[_ticker];
        delete tokenDecimals[_ticker];
        emit SupportRemoved(_ticker);
    }

    function updateSequencerUptimeFeed(address _sequencerUptimeFeed) external {
        sequencerUptimeFeed = _sequencerUptimeFeed;
    }

    function setTimeToExpiration(uint48 _timeToExpiration) external {
        timeToExpiration = _timeToExpiration;
    }

    function clearInvalidRequest(bytes32 _requestId) external {
        if (requestData.contains(_requestId)) {
            if (!requestData.remove(_requestId)) revert PriceFeed_FailedToClearRequest();
        }
    }

    /**
     * @notice Sends an HTTP request for character information
     * @param args The arguments to pass to the HTTP request -> should be the tickers for which pricing is requested
     * @return requestKey The ID of the request
     */
    function requestPriceUpdate(string[] calldata args, address _requester)
        external
        payable
        returns (bytes32 requestKey)
    {
        args;
        // Create a  request key
        requestKey = keccak256(abi.encode("PRICE REQUEST"));
        bytes32 requestId = keccak256(abi.encode("PRICE REQUEST"));

        RequestData memory data = RequestData({
            marketId: bytes32(0).toId(),
            requester: _requester,
            blockTimestamp: _blockTimestamp(),
            requestType: RequestType.PRICE_UPDATE,
            args: args
        });

        // Add the Request to Storage
        requestKeys.add(requestKey);
        idToKey[requestId] = requestKey;
        keyToId[requestKey] = requestId;
        requestData.set(requestId, data);
    }

    /// @dev - for this, we need to copy / call the function MarketUtils.calculateCumulativeMarketPnl but offchain
    function requestCumulativeMarketPnl(MarketId _id, address _requester)
        external
        payable
        returns (bytes32 requestKey)
    {
        // Create a  request id
        requestKey = keccak256(abi.encode("PRICE REQUEST"));
        bytes32 requestId = keccak256(abi.encode("PNL REQUEST"));

        string[] memory args;

        RequestData memory data = RequestData({
            marketId: _id,
            requester: _requester,
            blockTimestamp: _blockTimestamp(),
            requestType: RequestType.CUMULATIVE_PNL,
            args: args
        });

        // Add the Request to Storage
        requestKeys.add(requestKey);
        idToKey[requestId] = requestKey;
        keyToId[requestKey] = requestId;
        requestData.set(requestId, data);

        return requestId;
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    /// @dev - Need to make sure an err is only passed to the contract if it's critical,
    /// to prevent valid prices being invalidated.
    // Decode the response, according to the structure of the request
    // Try to avoid reverting, and instead return without storing the price response if invalid.
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        // Return if invalid requestId
        if (!requestData.contains(requestId)) return;
        // Return if an error is thrown
        if (err.length > 0) {
            _recreateRequest(requestId);
            return;
        }
        RequestData memory data = requestData.get(requestId);
        // Remove the RequestId from storage and return if fail
        if (!requestData.remove(requestId)) return;
        requestKeys.remove(idToKey[requestId]);
        delete idToKey[requestId];
        // Get the request type of the request
        if (data.requestType == RequestType.PRICE_UPDATE) {
            _decodeAndStorePrices(response);
        } else if (data.requestType == RequestType.CUMULATIVE_PNL) {
            _decodeAndStorePnl(response, data.marketId);
        } else {
            revert PriceFeed_InvalidRequestType();
        }

        // Emit an event to log the response
        emit Response(requestId, data, response, err);
    }

    /**
     * ================================== Private Functions ==================================
     */

    /// @dev Needed to re-request any failed requests to ensure they're fulfilled
    /// if a request fails > max retries, the request is cancelled and removed from storage.
    function _recreateRequest(bytes32 _oldRequestId) private {
        // get the failed request
        RequestData memory failedRequestData = requestData.get(_oldRequestId);
        // key will remain the same, so cache the key
        bytes32 requestKey = idToKey[_oldRequestId];
        // increment the number of retries
        if (numberOfRetries[requestKey] > maxRetries) {
            // delete the request to stop the loop
            requestData.remove(_oldRequestId);
            delete idToKey[_oldRequestId];
            requestKeys.remove(requestKey);
            delete keyToId[requestKey];
        } else {
            ++numberOfRetries[requestKey];
            // create a new request
            bytes32 newRequestId =
                _requestFulfillment(failedRequestData.args, failedRequestData.requestType == RequestType.PRICE_UPDATE);
            // replace the old request with the new one
            // Delete the old request
            requestData.remove(_oldRequestId);
            delete idToKey[_oldRequestId];
            idToKey[newRequestId] = requestKey;
            keyToId[requestKey] = newRequestId;
            requestData.set(newRequestId, failedRequestData);
        }
    }

    function _requestFulfillment(string[] memory _args, bool _isPrice) private returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(_isPrice ? priceUpdateSource : cumulativePnlSource); // Initialize the request with JS code
        if (_args.length > 0) req.setArgs(_args); // Set the arguments for the request

        // Send the request and store the request ID
        requestId = _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);
    }

    function _decodeAndStorePrices(bytes memory _encodedPrices) private {
        if (_encodedPrices.length > MAX_DATA_LENGTH) revert PriceFeed_PriceUpdateLength();
        if (_encodedPrices.length % WORD != 0) revert PriceFeed_PriceUpdateLength();

        uint256 numPrices = _encodedPrices.length / 32;

        for (uint16 i = 0; i < numPrices;) {
            bytes32 encodedPrice;

            // Use yul to extract the encoded price from the bytes
            // offset = (32 * i) + 32 (first 32 bytes are the length of the byte string)
            // encodedPrice = mload(encodedPrices[offset:offset+32])
            /// @solidity memory-safe-assembly
            assembly {
                encodedPrice := mload(add(_encodedPrices, add(32, mul(i, 32))))
            }

            Price memory price = Price(
                // First 15 bytes are the ticker
                bytes15(encodedPrice),
                // Next byte is the precision
                uint8(encodedPrice[15]),
                // Shift recorded values to the left and store the first 2 bytes (variance)
                uint16(bytes2(encodedPrice << 128)),
                // Shift recorded values to the left and store the first 6 bytes (timestamp)
                uint48(bytes6(encodedPrice << 144)),
                // Shift recorded values to the left and store the first 8 bytes (median price)
                uint64(bytes8(encodedPrice << 192))
            );

            // Store the constructed price struct in the mapping
            prices[price.ticker.fromSmallString()][price.timestamp] = price;

            unchecked {
                ++i;
            }
        }
    }

    function _decodeAndStorePnl(bytes memory _encodedPnl, MarketId marketId) private {
        uint256 len = _encodedPnl.length;
        if (len != PNL_BYTES) revert PriceFeed_InvalidResponseLength();

        Pnl memory pnl;

        bytes23 responseBytes = bytes23(_encodedPnl);
        // Truncate the first byte
        pnl.precision = uint8(bytes1(responseBytes));
        // shift the response 1 byte left, then truncate the first 6 bytes
        pnl.timestamp = uint48(bytes6(responseBytes << 8));
        // Extract the cumulativePnl as uint128 as we can't directly extract
        // an int128 from bytes.
        uint128 pnlValue = uint128(bytes16(responseBytes << 56));

        // Check if the most significant bit is 1 or 0
        // 0x800... in binary is 1000000... The msb is 1, and all of the rest are 0
        // Using the & operator, we check if the msb matches
        // If they match, the number is negative, else positive.
        if (pnlValue & MSB1 != 0) {
            // If msb is 1, this indicates the number is negative.
            // In this case, we flip all of the bits and add 1 to convert from +ve to -ve
            pnl.cumulativePnl = -int128(~pnlValue + 1);
        } else {
            // If msb is 0, the value is positive, so we convert and return as is.
            pnl.cumulativePnl = int128(pnlValue);
        }

        cumulativePnl[marketId][pnl.timestamp] = pnl;
    }

    function _blockTimestamp() internal view returns (uint48) {
        return uint48(block.timestamp);
    }

    function _generateKey(bytes memory _args) internal pure returns (bytes32) {
        return keccak256(_args);
    }

    // Used to pack price data into a single bytes32 word for fulfillment
    function encodePrices(
        string[] calldata _tickers,
        uint8[] calldata _precisions,
        uint16[] calldata _variances,
        uint48[] calldata _timestamps,
        uint64[] calldata _meds
    ) external pure returns (bytes memory) {
        uint16 len = uint16(_tickers.length);
        bytes32[] memory encodedPrices = new bytes32[](len);
        // Loop through the prices and encode them into a single bytes32 word
        for (uint16 i = 0; i < len;) {
            bytes32 encodedPrice = bytes32(
                abi.encodePacked(bytes15(bytes(_tickers[i])), _precisions[i], _variances[i], _timestamps[i], _meds[i])
            );
            encodedPrices[i] = encodedPrice;
            unchecked {
                ++i;
            }
        }
        // Concatenate the encoded prices into a single bytes string
        return abi.encodePacked(encodedPrices);
    }

    // Used to pack cumulative PNL into a single bytes32 word for fulfillment
    function encodePnl(uint8 _precision, uint48 _timestamp, int128 _cumulativePnl)
        external
        pure
        returns (bytes memory)
    {
        Pnl memory pnl;
        pnl.precision = _precision;
        pnl.timestamp = _timestamp;
        pnl.cumulativePnl = _cumulativePnl;
        return abi.encodePacked(pnl.precision, pnl.timestamp, pnl.cumulativePnl);
    }

    function getPrices(string memory _ticker, uint48 _timestamp) external view returns (Price memory signedPrices) {
        signedPrices = prices[_ticker][_timestamp];
        if (signedPrices.timestamp == 0) revert PriceFeed_PriceRequired(_ticker);
        if (signedPrices.timestamp + MIN_EXPIRATION_TIME < block.timestamp) revert PriceFeed_PriceExpired();
    }

    function getCumulativePnl(MarketId marketId, uint48 _timestamp) external view returns (Pnl memory pnl) {
        pnl = cumulativePnl[marketId][_timestamp];
        if (pnl.timestamp == 0) revert PriceFeed_PnlNotSigned();
    }

    function getSecondaryStrategy(string memory _ticker) external view returns (SecondaryStrategy memory) {
        return strategies[_ticker];
    }

    function priceUpdateRequested(bytes32 _requestId) external view returns (bool) {
        return requestData.get(_requestId).requester != address(0);
    }

    function getRequester(bytes32 _requestId) external view returns (address) {
        return requestData.get(_requestId).requester;
    }

    function getRequestData(bytes32 _requestId) external view returns (RequestData memory) {
        return requestData.get(_requestId);
    }

    function isRequestValid(bytes32 _requestKey) external view returns (bool) {
        bytes32 requestId = keyToId[_requestKey];
        return requestData.contains(requestId);
    }

    function getRequestTimestamp(bytes32 _requestKey) external view returns (uint48) {
        bytes32 requestId = keyToId[_requestKey];
        return requestData.get(requestId).blockTimestamp;
    }

    function getRequests() external view returns (bytes32[] memory) {
        return requestData.keys();
    }

    // Used to Manually Set Prices for Testing
    function updatePrices(bytes memory _response) external {
        _decodeAndStorePrices(_response);
    }

    // Used to Manually Set Pnl for Testing
    function updatePnl(bytes memory _response, MarketId marketId) external {
        _decodeAndStorePnl(_response, marketId);
    }

    // Used to Manually Delete a Request
    function deleteRequest(bytes32 _requestKey) external {
        bytes32 requestId = keyToId[_requestKey];
        requestData.remove(requestId);
        requestKeys.remove(_requestKey);
        delete idToKey[requestId];
        delete keyToId[_requestKey];
    }
}
