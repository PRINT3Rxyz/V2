// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Oracle} from "../src/oracle/Oracle.sol";

interface IHelperConfig {
    struct NetworkConfig {
        Contracts contracts;
        uint64 subId;
        bytes32 donId;
        bool mockFeed;
    }

    struct Contracts {
        address weth;
        address usdc;
        address link;
        address uniV3SwapRouter;
        address uniV3Factory;
        address chainlinkRouter;
        address uniV2Factory;
        address pyth;
        address sequencerUptimeFeed;
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory);
}
