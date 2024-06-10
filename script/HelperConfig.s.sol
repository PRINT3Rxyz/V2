// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";
import {IPriceFeed} from "../src/oracle/interfaces/IPriceFeed.sol";
import {WETH} from "../src/tokens/WETH.sol";
import {Oracle} from "../src/oracle/Oracle.sol";
import {MockToken} from "../test/mocks/MockToken.sol";
import {IERC20} from "src/tokens/interfaces/IERC20.sol";
import {IHelperConfig} from "./IHelperConfig.s.sol";

contract HelperConfig is IHelperConfig, Script {
    NetworkConfig private activeNetworkConfig;

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 84532 || block.chainid == 845326957) {
            activeNetworkConfig = getBaseSepoliaConfig();
        } else if (block.chainid == 8453) {
            activeNetworkConfig = getBaseConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getBaseSepoliaConfig() public returns (NetworkConfig memory baseSepoliaConfig) {
        MockUSDC mockUsdc = MockUSDC(0x9881f8b307CC3383500b432a8Ce9597fAfc73A77);
        WETH weth = WETH(0xD8eca5111c93EEf563FAB704F2C6A8DD7A12c77D);
        IERC20 link = IERC20(0xE4aB69C077896252FAFBD49EFD26B5D171A32410);

        baseSepoliaConfig.contracts.weth = address(weth);
        baseSepoliaConfig.contracts.usdc = address(mockUsdc);
        baseSepoliaConfig.contracts.link = address(link);
        baseSepoliaConfig.contracts.uniV3SwapRouter = 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4;
        baseSepoliaConfig.contracts.uniV3Factory = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
        baseSepoliaConfig.contracts.uniV2Factory = address(0);
        baseSepoliaConfig.contracts.nativeLinkUsdFeed = 0xb113F5A928BCfF189C998ab20d753a47F9dE5A61;

        baseSepoliaConfig.contracts.pyth = 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729;
        baseSepoliaConfig.subId = 54;
        baseSepoliaConfig.donId = 0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000;
        baseSepoliaConfig.contracts.chainlinkRouter = 0xf9B8fc078197181C841c296C876945aaa425B278;
        baseSepoliaConfig.mockFeed = false;
        baseSepoliaConfig.contracts.sequencerUptimeFeed = address(0);

        activeNetworkConfig = baseSepoliaConfig;
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getBaseConfig() public view returns (NetworkConfig memory baseConfig) {
        // Need to configurate Price Feed for Base and return
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory anvilConfig) {
        MockUSDC mockUsdc = new MockUSDC();
        WETH weth = new WETH();
        MockToken link = new MockToken();

        anvilConfig.contracts.weth = address(weth);
        anvilConfig.contracts.usdc = address(mockUsdc);
        anvilConfig.contracts.link = address(link);
        anvilConfig.contracts.uniV3SwapRouter = address(0);
        anvilConfig.contracts.uniV3Factory = address(0);
        anvilConfig.contracts.uniV2Factory = address(0);
        anvilConfig.contracts.pyth = address(0);
        anvilConfig.subId = 0;
        anvilConfig.donId = keccak256(abi.encode("DON"));
        anvilConfig.contracts.chainlinkRouter = address(0);
        anvilConfig.mockFeed = true;
        anvilConfig.contracts.sequencerUptimeFeed = address(0);

        activeNetworkConfig = anvilConfig;
    }
}
