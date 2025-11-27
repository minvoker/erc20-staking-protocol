// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {StakingPool} from "../src/StakingPool.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy reward token
        RewardToken token = new RewardToken(
            "Staking Reward Token",
            "STRWD",
            1_000_000 ether // 1 million tokens
        );

        // Deploy staking pool
        StakingPool pool = new StakingPool(address(token));

        vm.stopBroadcast();

        // Log addresses
        console.log("RewardToken deployed at:", address(token));
        console.log("StakingPool deployed at:", address(pool));
    }
}
