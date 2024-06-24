// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";
import {IMarket} from "src/markets/Market.sol";
import {MarketFactory, IMarketFactory} from "src/factory/MarketFactory.sol";
import {PriceFeed, IPriceFeed} from "src/oracle/PriceFeed.sol";
import {TradeStorage, ITradeStorage} from "src/positions/TradeStorage.sol";
import {ReferralStorage} from "src/referrals/ReferralStorage.sol";
import {PositionManager} from "src/router/PositionManager.sol";
import {Router} from "src/router/Router.sol";
import {WETH} from "src/tokens/WETH.sol";
import {Oracle} from "src/oracle/Oracle.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {Position} from "src/positions/Position.sol";
import {MarketUtils} from "src/markets/MarketUtils.sol";
import {GlobalRewardTracker} from "src/rewards/GlobalRewardTracker.sol";
import {FeeDistributor} from "src/rewards/FeeDistributor.sol";
import {MathUtils} from "src/libraries/MathUtils.sol";
import {MarketId} from "src/types/MarketId.sol";
import {TradeEngine} from "src/positions/TradeEngine.sol";
import {IVault} from "src/markets/Vault.sol";
import {LibString} from "src/libraries/LibString.sol";
import {IERC20} from "src/tokens/interfaces/IERC20.sol";

contract TestPriceFeed is Test {
    using LibString for bytes15;

    MarketFactory marketFactory;
    PriceFeed priceFeed;
    ITradeStorage tradeStorage;
    ReferralStorage referralStorage;
    PositionManager positionManager;
    TradeEngine tradeEngine;
    Router router;
    address OWNER;
    IMarket market;
    IVault vault;
    FeeDistributor feeDistributor;
    GlobalRewardTracker rewardTracker;

    address weth;
    address usdc;
    address link;

    MarketId marketId;

    string ethTicker = "ETH";
    string usdcTicker = "USDC";
    string[] tickers;

    address USER = makeAddr("USER");
    address USER1 = makeAddr("USER1");
    address USER2 = makeAddr("USER2");

    uint8[] precisions;
    uint16[] variances;
    uint48[] timestamps;
    uint64[] meds;

    /**
     * ==================================== Contract Vars ====================================
     */
    uint8 private constant WORD = 32;
    uint8 private constant PNL_BYTES = 23;
    uint128 private constant MSB1 = 0x80000000000000000000000000000000;
    uint64 private constant LINK_BASE_UNIT = 1e18;
    uint16 private constant MAX_DATA_LENGTH = 3296;
    uint8 private constant MAX_ARGS_LENGTH = 4;

    mapping(string ticker => mapping(uint48 blockTimestamp => IPriceFeed.Price priceResponse)) private prices;
    mapping(MarketId marketId => mapping(uint48 blockTimestamp => IPriceFeed.Pnl cumulativePnl)) public cumulativePnl;

    function setUp() public {
        Deploy deploy = new Deploy();
        Deploy.Contracts memory contracts = deploy.run();

        marketFactory = contracts.marketFactory;
        vm.label(address(marketFactory), "marketFactory");

        priceFeed = PriceFeed(address(contracts.priceFeed));
        vm.label(address(priceFeed), "priceFeed");

        referralStorage = contracts.referralStorage;
        vm.label(address(referralStorage), "referralStorage");

        positionManager = contracts.positionManager;
        vm.label(address(positionManager), "positionManager");

        router = contracts.router;
        vm.label(address(router), "router");

        market = contracts.market;
        vm.label(address(market), "market");

        tradeStorage = contracts.tradeStorage;
        vm.label(address(tradeStorage), "tradeStorage");

        tradeEngine = contracts.tradeEngine;
        vm.label(address(tradeEngine), "tradeEngine");

        feeDistributor = contracts.feeDistributor;
        vm.label(address(feeDistributor), "feeDistributor");

        OWNER = contracts.owner;
        (weth, usdc, link,,,) = deploy.helperContracts();
        tickers.push(ethTicker);
        tickers.push(usdcTicker);
        // Pass some time so block timestamp isn't 0
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
    }

    receive() external payable {}

    function test_supporting_an_asset_updates_state_correctly(
        uint256 _string,
        uint8 _randomDecimals,
        bool _exists,
        bool _feedTypeChainlink,
        address _feedAddress,
        bytes32 _feedId
    ) public {
        vm.assume(_string > 1000);

        IPriceFeed.SecondaryStrategy memory strategy = IPriceFeed.SecondaryStrategy({
            exists: _exists,
            feedType: _feedTypeChainlink ? IPriceFeed.FeedType.CHAINLINK : IPriceFeed.FeedType.PYTH,
            feedAddress: _feedAddress,
            feedId: _feedId
        });

        string memory randomString = string(abi.encodePacked(_string));

        vm.prank(address(marketFactory));
        priceFeed.supportAsset(randomString, strategy, _randomDecimals);

        // Check State has updated

        assertTrue(priceFeed.isValidAsset(randomString));
        assertEq(keccak256(abi.encode(strategy)), keccak256(abi.encode(priceFeed.getSecondaryStrategy(randomString))));
        assertEq(_randomDecimals, priceFeed.tokenDecimals(randomString));
    }

    function test_unsupporting_an_asset_removes_state_from_storage(
        uint256 _string,
        uint8 _randomDecimals,
        bool _exists,
        bool _feedTypeChainlink,
        address _feedAddress,
        bytes32 _feedId
    ) public {
        vm.assume(_string > 1000);

        IPriceFeed.SecondaryStrategy memory strategy = IPriceFeed.SecondaryStrategy({
            exists: _exists,
            feedType: _feedTypeChainlink ? IPriceFeed.FeedType.CHAINLINK : IPriceFeed.FeedType.PYTH,
            feedAddress: _feedAddress,
            feedId: _feedId
        });

        string memory randomString = string(abi.encodePacked(_string));

        vm.prank(address(marketFactory));
        priceFeed.supportAsset(randomString, strategy, _randomDecimals);

        assertTrue(priceFeed.isValidAsset(randomString));
        assertEq(keccak256(abi.encode(strategy)), keccak256(abi.encode(priceFeed.getSecondaryStrategy(randomString))));
        assertEq(_randomDecimals, priceFeed.tokenDecimals(randomString));

        vm.prank(OWNER);
        priceFeed.unsupportAsset(randomString);

        assertFalse(priceFeed.isValidAsset(randomString));
        assertNotEq(
            keccak256(abi.encode(strategy)), keccak256(abi.encode(priceFeed.getSecondaryStrategy(randomString)))
        );
        assertEq(0, priceFeed.tokenDecimals(randomString));
    }

    string[] tickersToEncode = ["ETH", "USDC", "BTC", "HARRYPOTTER", "!#$?/-_{`~];}"];
    uint8[] precisionsToEncode = [2, 3, 8, 6, 4];
    uint16[] variancesToEncode = [100, 200, 300, 400, 500];
    uint48[] timestampsToEncode = [1142141, 2124124, 3123049, 44102142, 52148120];
    uint64[] medsToEncode = [4200_00, 1_050, 72193_23000000, 345, 4];

    function test_decoding_price_responses(uint64 _rMed1, uint64 _rMed2, uint64 _rMed3, uint64 _rMed4, uint64 _rMed5)
        public
    {
        medsToEncode[0] = _rMed1;
        medsToEncode[1] = _rMed2;
        medsToEncode[2] = _rMed3;
        medsToEncode[3] = _rMed4;
        medsToEncode[4] = _rMed5;

        bytes memory encodedPrices = Oracle.encodePrices(
            tickersToEncode, precisionsToEncode, variancesToEncode, timestampsToEncode, medsToEncode
        );

        _decodeAndStorePrices(encodedPrices);

        for (uint16 i = 0; i < tickersToEncode.length; i++) {
            string memory ticker = tickersToEncode[i];
            uint48 timestamp = timestampsToEncode[i];

            IPriceFeed.Price memory price = prices[ticker][timestamp];

            assertEq(ticker, price.ticker.fromSmallString());
            assertEq(precisionsToEncode[i], price.precision);
            assertEq(variancesToEncode[i], price.variance);
            assertEq(timestampsToEncode[i], price.timestamp);
            assertEq(medsToEncode[i], price.med);
        }
    }

    function test_decoding_pnl_responses(uint8 _rPrecision, uint48 _rTimestamp, int128 _rCumulativePnl) public {
        // bound between min + 1 and max -1
        _rCumulativePnl = int128(bound(_rCumulativePnl, type(int128).min + 1, type(int128).max - 1));

        bytes memory encodedPnl = Oracle.encodePnl(_rPrecision, _rTimestamp, _rCumulativePnl);

        _decodeAndStorePnl(encodedPnl);

        IPriceFeed.Pnl memory pnl = cumulativePnl[marketId][_rTimestamp];

        assertEq(_rPrecision, pnl.precision);
        assertEq(_rTimestamp, pnl.timestamp);
        assertEq(_rCumulativePnl, pnl.cumulativePnl);
    }

    /**
     * ==================================== Internal / Private Functions ====================================
     */
    function _decodeAndStorePrices(bytes memory _encodedPrices) private {
        if (_encodedPrices.length > MAX_DATA_LENGTH) revert("Update Length");
        if (_encodedPrices.length % WORD != 0) revert("Update Length");

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

            IPriceFeed.Price memory price = IPriceFeed.Price(
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

            string memory ticker = price.ticker.fromSmallString();

            prices[ticker][price.timestamp] = price;

            unchecked {
                ++i;
            }
        }
    }

    function _decodeAndStorePnl(bytes memory _encodedPnl) private {
        uint256 len = _encodedPnl.length;
        if (len != PNL_BYTES) revert("Response Length");

        IPriceFeed.Pnl memory pnl;

        bytes23 responseBytes = bytes23(_encodedPnl);
        console.logBytes23(responseBytes);
        // Truncate the first byte
        pnl.precision = uint8(bytes1(responseBytes));
        console2.log("Precision: ", pnl.precision);
        // shift the response 1 byte left, then truncate the first 6 bytes
        pnl.timestamp = uint48(bytes6(responseBytes << 8));
        console2.log("Timestamp: ", pnl.timestamp);
        // Extract the cumulativePnl as uint128 as we can't directly extract
        // an int128 from bytes.
        uint128 pnlValue = uint128(bytes16(responseBytes << 56));
        console2.log("Pnl Value: ", pnlValue);
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

        console2.log("Cumulative Pnl: ", pnl.cumulativePnl);

        cumulativePnl[marketId][pnl.timestamp] = pnl;
    }
}
