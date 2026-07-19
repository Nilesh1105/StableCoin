//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

contract DeployDSCTest is Test {
    DeployDSC deployer;
    HelperConfig config;
    DecentralizedStableCoin dsc;
    DSCEngine engine;

    address wEth;
    address wBtc;
    address wEthPriceFeed;
    address wBtcPriceFeed;

    address alice = makeAddr("alice");

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();

        (wEth, wBtc, wEthPriceFeed, wBtcPriceFeed) = config.activeNetworkConfig();
    }

    function test__getUsdValueReturnsAsExpected() public view {
        uint256 ethQty = 15e18;
        uint256 expectedAmount = 30000e18;
        uint256 actualAmount = engine.getUsdValue(wEth, ethQty);
        assertEq(expectedAmount, actualAmount);
    }
}
