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
        WETH weth = WETH(0x4200000000000000000000000000000000000006);
        IERC20 link = IERC20(0xE4aB69C077896252FAFBD49EFD26B5D171A32410);

        baseSepoliaConfig.contracts.weth = address(weth);
        baseSepoliaConfig.contracts.usdc = address(mockUsdc);
        baseSepoliaConfig.contracts.link = address(link);
        baseSepoliaConfig.contracts.uniV3SwapRouter = 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4;
        baseSepoliaConfig.contracts.uniV3Factory = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
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

    function getBaseConfig() public returns (NetworkConfig memory baseConfig) {
        baseConfig.contracts.weth = 0x4200000000000000000000000000000000000006;
        baseConfig.contracts.usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        baseConfig.contracts.link = 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196;
        baseConfig.contracts.uniV3SwapRouter = 0x2626664c2603336E57B271c5C0b26F421741e481;
        baseConfig.contracts.uniV3Factory = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
        baseConfig.contracts.nativeLinkUsdFeed = 0x17CAb8FE31E32f08326e5E27412894e49B0f9D65;

        baseConfig.contracts.pyth = 0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a;
        baseConfig.subId = 54;
        baseConfig.donId = 0x66756e2d626173652d6d61696e6e65742d310000000000000000000000000000;
        baseConfig.contracts.chainlinkRouter = 0xf9B8fc078197181C841c296C876945aaa425B278;
        baseConfig.mockFeed = false;
        baseConfig.contracts.sequencerUptimeFeed = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;

        activeNetworkConfig = baseConfig;
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
        anvilConfig.contracts.pyth = address(0);
        anvilConfig.subId = 0;
        anvilConfig.donId = keccak256(abi.encode("DON"));
        anvilConfig.contracts.chainlinkRouter = address(0);
        anvilConfig.mockFeed = true;
        anvilConfig.contracts.sequencerUptimeFeed = address(0);

        activeNetworkConfig = anvilConfig;
    }
}
