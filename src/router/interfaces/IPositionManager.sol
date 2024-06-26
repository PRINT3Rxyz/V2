// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Position} from "../../positions/Position.sol";
import {IVault} from "../../markets/interfaces/IVault.sol";
import {IPriceFeed} from "../../oracle/interfaces/IPriceFeed.sol";
import {MarketId} from "../../types/MarketId.sol";

interface IPositionManager {
    event ExecutePosition(bytes32 indexed marketId, bytes32 indexed _orderKey, uint256 _fee, uint256 _feeDiscount);
    event GasLimitsUpdated(
        uint256 indexed depositGasLimit, uint256 indexed withdrawalGasLimit, uint256 indexed positionGasLimit
    );
    event AdlExecuted(MarketId indexed market, bytes32 indexed positionKey, uint256 sizeDelta, bool isLong);
    event AdlTargetRatioReached(MarketId indexed market, int256 newFactor, bool isLong);
    event MarketRequestCancelled(bytes32 indexed _requestKey, address indexed _owner, address _token, uint256 _amount);
    event PositionManager_HoldingTokens(address indexed user, address indexed amount, address indexed token);

    error PositionManager_AccessDenied();
    error PositionManager_CancellationFailed();
    error PositionManager_InvalidMarket();
    error PositionManager_InvalidKey();
    error PositionManager_ExecuteDepositFailed();
    error PositionManager_ExecuteWithdrawalFailed();
    error PositionManager_InvalidRequestType();
    error PositionManager_LiquidationFailed();
    error PositionManager_RequestDoesNotExist();
    error PositionManager_NotPositionOwner();
    error PositionManager_InsufficientDelay();
    error PositionManager_PTPRatioNotExceeded();
    error PositionManager_LongSideNotFlagged();
    error PositionManager_ShortSideNotFlagged();
    error PositionManager_PositionNotActive();
    error PositionManager_PNLFactorNotReduced();
    error PositionManager_InvalidPrice();
    error PositionManager_PriceAlreadyUpdated();
    error PositionManager_PnlToPoolRatioNotExceeded(int256 pnlFactor, uint256 maxPnlFactor);
    error PositionManager_PriceUpdateFee();
    error PositionManager_InvalidDepositOwner();
    error PositionManager_DepositNotExpired();
    error PositionManager_InvalidWithdrawalOwner();
    error PositionManager_WithdrawalNotExpired();
    error PositionManager_InvalidTransferIn();
    error PositionManager_InvalidDeposit();
    error PositionManager_InvalidWithdrawal();
    error PositionManager_AdlFailed();

    function updatePriceFeed(IPriceFeed _priceFeed) external;
    function averageDepositCost() external view returns (uint256);
    function averageWithdrawalCost() external view returns (uint256);
    function averagePositionCost() external view returns (uint256);
    function baseGasLimit() external view returns (uint256);
    function transferTokensForIncrease(
        IVault vault,
        address _collateralToken,
        uint256 _collateralDelta,
        uint256 _affiliateRebate,
        uint256 _feeForExecutor,
        address _executor
    ) external;
}
