// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {MarketFactory} from "src/factory/MarketFactory.sol";
import {TradeStorage} from "src/positions/TradeStorage.sol";
import {TradeEngine} from "src/positions/TradeEngine.sol";
import {Vault} from "src/markets/Vault.sol";

contract ReplaceTradeEngine is Script {
    address oldTradeEngine;

    MarketFactory marketFactory;

    TradeStorage tradeStorage;

    address market;

    // Array of vaults to replace the trade engine for
    address[] vaults;

    function run() public {
        vm.startBroadcast();

        TradeEngine tradeEngine = new TradeEngine(address(tradeStorage), market);

        marketFactory.updateTradeEngine(address(tradeEngine));

        tradeStorage.updateTradeEngine(address(tradeEngine));

        for (uint256 i = 0; i < vaults.length;) {
            Vault vault = Vault(payable(vaults[i]));
            vault.replaceTradeEngine(oldTradeEngine, address(tradeEngine));
            unchecked {
                ++i;
            }
        }

        vm.stopBroadcast();
    }
}
