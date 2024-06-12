// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {Router} from "src/router/Router.sol";
import {IPositionManager} from "src/router/PositionManager.sol";
import {MarketId, MarketIdLibrary} from "src/types/MarketId.sol";
import {IPriceFeed} from "src/oracle/interfaces/IPriceFeed.sol";

contract CreateDeposit is Script {
    Router router = Router(payable(0xC656197971FAd28D5F8C7F5424af55ed0f10D753));
    MarketId marketId = MarketIdLibrary.toId(0x69b9cda3342215535520e6b157ca90560845ae7d1e75fa59beebef34a49118ab);
    IPriceFeed priceFeed = IPriceFeed(0x4e6D2BbA749BE535C7AC1C2124060504E7801291);
    IPositionManager positionManager = IPositionManager(0xdF1f52F5020DEaF52C52B00367c63928771E7D71);
    address weth = 0xD8eca5111c93EEf563FAB704F2C6A8DD7A12c77D;
    address usdc = 0x9881f8b307CC3383500b432a8Ce9597fAfc73A77;
    uint256 amountIn = 0.01 ether;
    bool isLong = true;
    uint40 stakeDuration = 0 minutes;
    bool shouldWrap = true;

    function run() public {
        uint256 executionFee = 0.00001 ether;
        uint256 valueToSend;
        if (shouldWrap && isLong) {
            valueToSend = amountIn + executionFee;
        } else {
            valueToSend = executionFee;
        }
        // Create Deposit
        vm.broadcast();
        router.createDeposit{value: valueToSend}(
            marketId, msg.sender, isLong ? weth : usdc, amountIn, executionFee, stakeDuration, shouldWrap
        );

        // After the Price Request has been Fulfilled, run the execute script.
    }
}
