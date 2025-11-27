// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StakingPool} from "../src/StakingPool.sol";
import {RewardToken} from "../src/RewardToken.sol";

contract StakingPoolTest is Test {
    StakingPool public pool;
    RewardToken public token;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    uint256 constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 constant STAKE_AMOUNT = 1000e18;
    uint256 constant REWARD_AMOUNT = 10_000e18;

    function setUp() public {
        // Deploy token
        token = new RewardToken("Reward Token", "RWD", INITIAL_SUPPLY);

        // Deploy staking pool
        pool = new StakingPool(address(token));

        // Give users some tokens
        token.transfer(user1, 10_000e18);
        token.transfer(user2, 10_000e18);

        // Approve pool to spend tokens
        vm.prank(user1);
        token.approve(address(pool), type(uint256).max);

        vm.prank(user2);
        token.approve(address(pool), type(uint256).max);
    }

    function testStake() public {
        vm.startPrank(user1);

        uint256 balanceBefore = token.balanceOf(user1);
        pool.stake(STAKE_AMOUNT);
        uint256 balanceAfter = token.balanceOf(user1);

        assertEq(balanceAfter, balanceBefore - STAKE_AMOUNT);
        assertEq(pool.balanceOf(user1), STAKE_AMOUNT);
        assertEq(pool.totalSupply(), STAKE_AMOUNT);

        vm.stopPrank();
    }

    function testCannotStakeZero() public {
        vm.startPrank(user1);
        vm.expectRevert("Cannot stake 0");
        pool.stake(0);
        vm.stopPrank();
    }

    function testWithdraw() public {
        // First stake
        vm.startPrank(user1);
        pool.stake(STAKE_AMOUNT);

        // Then withdraw
        uint256 balanceBefore = token.balanceOf(user1);
        pool.withdraw(STAKE_AMOUNT);
        uint256 balanceAfter = token.balanceOf(user1);

        assertEq(balanceAfter, balanceBefore + STAKE_AMOUNT);
        assertEq(pool.balanceOf(user1), 0);
        assertEq(pool.totalSupply(), 0);

        vm.stopPrank();
    }

    function testCannotWithdrawMoreThanStaked() public {
        vm.startPrank(user1);
        pool.stake(STAKE_AMOUNT);

        vm.expectRevert("Insufficient staked balance");
        pool.withdraw(STAKE_AMOUNT + 1);

        vm.stopPrank();
    }

    function testEarnRewards() public {
        // Add rewards to pool
        token.transfer(address(pool), REWARD_AMOUNT);
        pool.notifyRewardAmount(REWARD_AMOUNT);

        // User1 stakes
        vm.prank(user1);
        pool.stake(STAKE_AMOUNT);

        // Fast forward 1 day
        vm.warp(block.timestamp + 1 days);

        // Check earned rewards
        uint256 earned = pool.earned(user1);
        assertGt(earned, 0, "Should have earned rewards");

        console.log("Earned after 1 day:", earned / 1e18, "tokens");
    }

    function testClaimRewards() public {
        // Add rewards
        token.transfer(address(pool), REWARD_AMOUNT);
        pool.notifyRewardAmount(REWARD_AMOUNT);

        // User stakes
        vm.prank(user1);
        pool.stake(STAKE_AMOUNT);

        // Fast forward 1 day
        vm.warp(block.timestamp + 1 days);

        // Claim rewards
        uint256 balanceBefore = token.balanceOf(user1);
        vm.prank(user1);
        pool.getReward();
        uint256 balanceAfter = token.balanceOf(user1);

        assertGt(balanceAfter, balanceBefore, "Should receive rewards");
        assertEq(pool.earned(user1), 0, "Earned should be 0 after claim");
    }

    function testMultipleUsers() public {
        // Add rewards
        token.transfer(address(pool), REWARD_AMOUNT);
        pool.notifyRewardAmount(REWARD_AMOUNT);

        // User1 stakes 1000
        vm.prank(user1);
        pool.stake(1000e18);

        // Wait 12 hours
        vm.warp(block.timestamp + 12 hours);

        // User2 stakes 1000 (equal stake but later)
        vm.prank(user2);
        pool.stake(1000e18);

        // Wait another 12 hours
        vm.warp(block.timestamp + 12 hours);

        uint256 earned1 = pool.earned(user1);
        uint256 earned2 = pool.earned(user2);

        console.log("User1 earned:", earned1 / 1e18);
        console.log("User2 earned:", earned2 / 1e18);

        // User1 should have more (staked earlier for full 24h vs User2's 12h)
        assertGt(earned1, earned2, "User1 should earn more (staked first)");
    }

    function testEmergencyWithdraw() public {
        // Add rewards
        token.transfer(address(pool), REWARD_AMOUNT);
        pool.notifyRewardAmount(REWARD_AMOUNT);

        // User stakes
        vm.prank(user1);
        pool.stake(STAKE_AMOUNT);

        // Fast forward to earn rewards
        vm.warp(block.timestamp + 1 days);

        uint256 earnedBefore = pool.earned(user1);
        assertGt(earnedBefore, 0, "Should have earned rewards");

        // Emergency withdraw (forfeit rewards)
        uint256 balanceBefore = token.balanceOf(user1);
        vm.prank(user1);
        pool.emergencyWithdraw();
        uint256 balanceAfter = token.balanceOf(user1);

        // Gets stake back but NO rewards
        assertEq(balanceAfter, balanceBefore + STAKE_AMOUNT);
        assertEq(pool.balanceOf(user1), 0);
        assertEq(pool.earned(user1), 0);
    }

    function testGetStakeInfo() public {
        // Add rewards
        token.transfer(address(pool), REWARD_AMOUNT);
        pool.notifyRewardAmount(REWARD_AMOUNT);

        // User stakes
        vm.prank(user1);
        pool.stake(STAKE_AMOUNT);

        (uint256 staked, uint256 earned, uint256 rate, uint256 periodEnd) =
            pool.getStakeInfo(user1);

        assertEq(staked, STAKE_AMOUNT);
        assertEq(earned, 0); // Just staked, no time passed
        assertGt(rate, 0);
        assertGt(periodEnd, block.timestamp);
    }
}
