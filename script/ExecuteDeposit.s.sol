// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {PositionManager} from "src/router/PositionManager.sol";
import {MarketId, MarketIdLibrary} from "src/types/MarketId.sol";

contract ExecuteDeposit is Script {
    PositionManager positionManager = PositionManager(payable(0xdF1f52F5020DEaF52C52B00367c63928771E7D71));
    MarketId marketId = MarketIdLibrary.toId(0x69b9cda3342215535520e6b157ca90560845ae7d1e75fa59beebef34a49118ab);
    // Replace with key of request
    bytes32 requestKey = 0x6fc89dc772623d9a7856301d7565218209e4d944889485e3f525d2a1ef59ddad;

    function run() public {
        vm.broadcast();
        positionManager.executeDeposit(marketId, requestKey);
    }
}
