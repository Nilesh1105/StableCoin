//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;

    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        config = new HelperConfig();
        (address wEth, address wBtc, address wEthPriceFeed, address wBtcPriceFeed, uint256 deployerKey) =
            config.activeNetworkConfig();

        tokenAddresses = [wEth, wBtc];
        priceFeedAddresses = [wEthPriceFeed, wBtcPriceFeed];

        vm.startBroadcast(deployerKey);
        address deployer = vm.addr(deployerKey);

        dsc = new DecentralizedStableCoin(deployer); //As of now this is zero, but later we will work on it.
        engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();

        return (dsc, engine, config);
    }
}
