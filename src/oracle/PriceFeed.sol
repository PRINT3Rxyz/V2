// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IMarket} from "../markets/interfaces/IMarket.sol";
import {EnumerableSetLib} from "../libraries/EnumerableSetLib.sol";
import {EnumerableMap} from "../libraries/EnumerableMap.sol";
import {OwnableRoles} from "../auth/OwnableRoles.sol";
import {IMarketFactory} from "../factory/interfaces/IMarketFactory.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";
import {IWETH} from "../tokens/interfaces/IWETH.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {ReentrancyGuard} from "../utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "../libraries/SafeTransferLib.sol";
import {Oracle} from "./Oracle.sol";
import {LibString} from "../../src/libraries/LibString.sol";
import {MarketId, MarketIdLibrary} from "../types/MarketId.sol";

contract PriceFeed is FunctionsClient, ReentrancyGuard, OwnableRoles, IPriceFeed {
    using FunctionsRequest for FunctionsRequest.Request;
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using EnumerableMap for EnumerableMap.PriceMap;
    using LibString for bytes15;
    using MarketIdLibrary for bytes32;

    uint256 public constant PRICE_DECIMALS = 30;

    uint8 private constant WORD = 32;
    uint8 private constant PNL_BYTES = 23;
    uint128 private constant MSB1 = 0x80000000000000000000000000000000;
    uint64 private constant LINK_BASE_UNIT = 1e18;
    uint16 private constant MAX_DATA_LENGTH = 3296;
    uint8 private constant MAX_ARGS_LENGTH = 4;

    address public immutable WETH;

    address public immutable LINK;

    IMarketFactory public marketFactory;
    IMarket market;

    // Don IDs: https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 private donId;
    address public pyth;
    address public sequencerUptimeFeed;
    bool private isInitialized;
    uint64 subscriptionId;

    bytes public encryptedSecretsUrls;
    // JavaScript source code
    // Hard coded javascript source code here for each request's execution function
    string priceUpdateSource;
    string cumulativePnlSource;

    //Callback gas limit
    uint256 public gasOverhead;
    uint256 public premiumFee;
    uint32 public callbackGasLimit;
    uint48 public timeToExpiration;

    mapping(string ticker => mapping(uint48 blockTimestamp => Price priceResponse)) private prices;
    mapping(MarketId marketId => mapping(uint48 blockTimestamp => Pnl cumulativePnl)) public cumulativePnl;

    mapping(string ticker => Price priceResponse) private lastPrice;
    mapping(MarketId marketId => Pnl cumulativePnl) public lastPnl;

    mapping(string ticker => SecondaryStrategy) private strategies;
    mapping(string ticker => uint8) public tokenDecimals;

    // Dictionary to enable clearing of the RequestKey
    // Bi-directional to handle the case of invalidated requests
    mapping(bytes32 requestId => bytes32 requestKey) private idToKey;
    mapping(bytes32 requestKey => bytes32 requestId) private keyToId;

    // Used to track whether a price has been attempted or not.
    mapping(bytes32 requestKey => bool attempted) public fullfillmentAttempted;

    EnumerableMap.PriceMap private requestData;
    EnumerableSetLib.Bytes32Set private assetIds;
    EnumerableSetLib.Bytes32Set private requestKeys;

    modifier onlyFactoryOrRouter() {
        if (rolesOf(msg.sender) != _ROLE_0 && rolesOf(msg.sender) != _ROLE_3) revert Unauthorized();
        _;
    }

    constructor(
        address _marketFactory,
        address _weth,
        address _link,
        address _pyth,
        uint64 _subId,
        bytes32 _donId,
        address _functionsRouter
    ) FunctionsClient(_functionsRouter) {
        _initializeOwner(msg.sender);
        marketFactory = IMarketFactory(_marketFactory);
        WETH = _weth;
        LINK = _link;
        pyth = _pyth;
        subscriptionId = _subId;
        donId = _donId;
    }

    function initialize(
        string calldata _priceUpdateSource,
        string calldata _cumulativePnlSource,
        uint256 _gasOverhead,
        uint32 _callbackGasLimit,
        uint256 _premiumFee,
        address _sequencerUptimeFeed,
        uint48 _timeToExpiration
    ) external onlyOwner {
        if (isInitialized) revert PriceFeed_AlreadyInitialized();
        priceUpdateSource = _priceUpdateSource;
        cumulativePnlSource = _cumulativePnlSource;
        gasOverhead = _gasOverhead;
        callbackGasLimit = _callbackGasLimit;
        premiumFee = _premiumFee;
        sequencerUptimeFeed = _sequencerUptimeFeed;
        timeToExpiration = _timeToExpiration;
        isInitialized = true;
    }

    function updateBillingParameters(
        uint64 _subId,
        bytes32 _donId,
        uint256 _gasOverhead,
        uint32 _callbackGasLimit,
        uint256 _premiumFee
    ) external onlyOwner {
        subscriptionId = _subId;
        donId = _donId;
        gasOverhead = _gasOverhead;
        callbackGasLimit = _callbackGasLimit;
        premiumFee = _premiumFee;
    }

    function setEncryptedSecretUrls(bytes calldata _encryptedSecretsUrls) external onlyOwner {
        encryptedSecretsUrls = _encryptedSecretsUrls;
    }

    function updateFunctions(string memory _priceUpdateSource, string memory _cumulativePnlSource) external onlyOwner {
        priceUpdateSource = _priceUpdateSource;
        cumulativePnlSource = _cumulativePnlSource;
    }

    function supportAsset(string memory _ticker, SecondaryStrategy calldata _strategy, uint8 _tokenDecimals)
        external
        onlyRoles(_ROLE_0)
    {
        bytes32 assetId = keccak256(abi.encode(_ticker));
        if (assetIds.contains(assetId)) return; // Return if already supported
        bool success = assetIds.add(assetId);
        if (!success) revert PriceFeed_AssetSupportFailed();
        strategies[_ticker] = _strategy;
        tokenDecimals[_ticker] = _tokenDecimals;
        emit AssetSupported(_ticker, _tokenDecimals);
    }

    function unsupportAsset(string memory _ticker) external onlyOwner {
        bytes32 assetId = keccak256(abi.encode(_ticker));
        if (!assetIds.contains(assetId)) return; // Return if not supported
        bool success = assetIds.remove(assetId);
        if (!success) revert PriceFeed_AssetRemovalFailed();
        delete strategies[_ticker];
        delete tokenDecimals[_ticker];
        emit SupportRemoved(_ticker);
    }

    function updateDataFeeds(address _pyth, address _sequencerUptimeFeed) external onlyOwner {
        pyth = _pyth;
        sequencerUptimeFeed = _sequencerUptimeFeed;
    }

    function updateSecondaryStrategy(string memory _ticker, SecondaryStrategy memory _strategy) external onlyOwner {
        strategies[_ticker] = _strategy;
    }

    function setTimeToExpiration(uint48 _timeToExpiration) external onlyOwner {
        timeToExpiration = _timeToExpiration;
    }

    function clearInvalidRequest(bytes32 _requestId) external onlyOwner {
        if (requestData.contains(_requestId)) {
            if (!requestData.remove(_requestId)) revert PriceFeed_FailedToClearRequest();
        }
    }

    /**
     * @notice Sends an HTTP request for character information
     * @param args The arguments to pass to the HTTP request -> should be the tickers for which pricing is requested
     * @return requestKey The signature of the request
     */
    function requestPriceUpdate(string[] calldata args, address _requester)
        external
        payable
        onlyFactoryOrRouter
        nonReentrant
        returns (bytes32)
    {
        Oracle.isSequencerUp(this);

        uint48 blockTimestamp = _blockTimestamp();

        if (args.length > MAX_ARGS_LENGTH) revert PriceFeed_InvalidArgsLength();

        bytes32 requestKey = _generateKey(abi.encode(args, _requester, blockTimestamp));

        if (requestKeys.contains(requestKey)) return requestKey;

        bytes32 requestId = _requestFulfillment(args, true);

        RequestData memory data = RequestData({
            marketId: bytes32(0).toId(),
            requester: _requester,
            blockTimestamp: blockTimestamp,
            requestType: RequestType.PRICE_UPDATE,
            args: args
        });

        requestKeys.add(requestKey);
        idToKey[requestId] = requestKey;
        keyToId[requestKey] = requestId;
        requestData.set(requestId, data);

        return requestKey;
    }

    /**
     * @notice - Needs a subgraph entity to store open interest
     * values for historical blocks to enable for querying historical pnl.
     */
    function requestCumulativeMarketPnl(MarketId _id, address _requester)
        external
        payable
        onlyRoles(_ROLE_3)
        nonReentrant
        returns (bytes32)
    {
        if (!marketFactory.isMarket(_id)) revert PriceFeed_InvalidMarket();

        Oracle.isSequencerUp(this);

        uint48 blockTimestamp = _blockTimestamp();

        string[] memory args = Oracle.constructPnlArguments(_id);

        bytes32 requestKey = _generateKey(abi.encode(args, _requester, blockTimestamp));

        if (requestKeys.contains(requestKey)) return requestKey;

        bytes32 requestId = _requestFulfillment(args, false);

        RequestData memory data = RequestData({
            marketId: _id,
            requester: _requester,
            blockTimestamp: blockTimestamp,
            requestType: RequestType.CUMULATIVE_PNL,
            args: args
        });

        // Add the Request to Storage
        requestKeys.add(requestKey);
        idToKey[requestId] = requestKey;
        keyToId[requestKey] = requestId;
        requestData.set(requestId, data);

        return requestKey;
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
        if (!requestData.contains(requestId)) return;

        bytes32 requestKey = idToKey[requestId];

        fullfillmentAttempted[requestKey] = true;

        if (err.length > 0) {
            // If it errors, remove the request from storage
            requestData.remove(requestId);
            requestKeys.remove(requestKey);
            delete idToKey[requestId];
            delete keyToId[requestKey];
            return;
        }

        RequestData memory data = requestData.get(requestId);

        if (!requestData.remove(requestId)) return;
        requestKeys.remove(requestKey);
        delete idToKey[requestId];
        delete keyToId[requestKey];

        if (data.requestType == RequestType.PRICE_UPDATE) {
            _decodeAndStorePrices(response);
        } else if (data.requestType == RequestType.CUMULATIVE_PNL) {
            _decodeAndStorePnl(response, data.marketId);
        } else {
            revert PriceFeed_InvalidRequestType();
        }

        emit Response(requestId, data, response, err);
    }

    // Eth must be settled to fund the Chainlink Functions Subscription
    function withdrawEthForSettlement() external onlyOwner nonReentrant {
        uint256 ethBalance = address(this).balance;

        if (ethBalance == 0) revert PriceFeed_ZeroBalance();

        SafeTransferLib.safeTransferETH(payable(msg.sender), ethBalance);
    }

    /**
     * ================================== Private Functions ==================================
     */
    function _requestFulfillment(string[] memory _args, bool _isPrice) private returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;

        req.initializeRequestForInlineJavaScript(_isPrice ? priceUpdateSource : cumulativePnlSource);

        req.addSecretsReference(encryptedSecretsUrls);

        if (_args.length > 0) req.setArgs(_args);

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

            if (!Oracle.validatePrice(this, price)) return;

            string memory ticker = price.ticker.fromSmallString();

            prices[ticker][price.timestamp] = price;
            lastPrice[ticker] = price;

            emit PriceUpdated(price.ticker, price.timestamp, price.med, price.variance);

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
            // Can revert if pnl value is type(int128).max
            pnl.cumulativePnl = -int128(~pnlValue + 1);
        } else {
            // If msb is 0, the value is positive, so we convert and return as is.
            pnl.cumulativePnl = int128(pnlValue);
        }

        cumulativePnl[marketId][pnl.timestamp] = pnl;
        lastPnl[marketId] = pnl;

        emit PnlUpdated(MarketId.unwrap(marketId), pnl.timestamp, pnl.cumulativePnl);
    }

    function _blockTimestamp() internal view returns (uint48) {
        return uint48(block.timestamp);
    }

    function _generateKey(bytes memory _args) internal pure returns (bytes32) {
        return keccak256(_args);
    }

    /**
     * ================================== External / Getter Functions ==================================
     */
    function getPrices(string memory _ticker, uint48 _timestamp) external view returns (Price memory signedPrices) {
        signedPrices = prices[_ticker][_timestamp];
        if (signedPrices.timestamp == 0) revert PriceFeed_PriceRequired(_ticker);
        if (signedPrices.timestamp + timeToExpiration < block.timestamp) revert PriceFeed_PriceExpired();
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

    function isValidAsset(string memory _ticker) external view returns (bool) {
        return assetIds.contains(keccak256(abi.encode(_ticker)));
    }

    function getRequester(bytes32 _requestId) external view returns (address) {
        return requestData.get(_requestId).requester;
    }

    function getRequestData(bytes32 _requestKey) external view returns (RequestData memory) {
        bytes32 requestId = keyToId[_requestKey];
        return requestData.get(requestId);
    }

    function isRequestValid(bytes32 _requestKey) external view returns (bool) {
        bytes32 requestId = keyToId[_requestKey];
        if (requestData.contains(requestId)) {
            return requestData.get(requestId).blockTimestamp + timeToExpiration > block.timestamp;
        } else {
            return false;
        }
    }

    function getRequestTimestamp(bytes32 _requestKey) external view returns (uint48) {
        bytes32 requestId = keyToId[_requestKey];
        return requestData.get(requestId).blockTimestamp;
    }

    function getRequests() external view returns (bytes32[] memory) {
        return requestData.keys();
    }

    function getLastPrice(string memory _ticker) external view returns (Price memory) {
        return lastPrice[_ticker];
    }

    function getLastPnl(MarketId _id) external view returns (Pnl memory) {
        return lastPnl[_id];
    }
}
