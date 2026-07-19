//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wEth;
        address wBtc;
        address wEthPriceFeed;
        address wBtcPriceFeed;
        uint256 deployerKey;
    }

    NetworkConfig activeNetworkConfig;

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant SEPOLIA_DEPLOYER_KEY = 0; //Currently set to 0
    uint256 private constant ANVIL_DEPLOYER_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_PRICE = 2000e8;
    int256 public constant BTC_PRICE = 10000e8;

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            wEth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wBtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            wEthPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wBtcPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            deployerKey: vm.envUint("SEPOLIA_DEPLOYER_KEY")
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        if (activeNetworkConfig.wEth != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        ERC20Mock wEthMock = new ERC20Mock();
        MockV3Aggregator wEthPriceFeedMock = new MockV3Aggregator(DECIMALS, ETH_PRICE);

        ERC20Mock wBtcMock = new ERC20Mock();
        MockV3Aggregator wBtcPriceFeedMock = new MockV3Aggregator(DECIMALS, BTC_PRICE);
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            wEth: address(wEthMock),
            wBtc: address(wBtcMock),
            wEthPriceFeed: address(wEthPriceFeedMock),
            wBtcPriceFeed: address(wBtcPriceFeedMock),
            deployerKey: ANVIL_DEPLOYER_KEY
        });

        activeNetworkConfig = anvilNetworkConfig;
    }
}
