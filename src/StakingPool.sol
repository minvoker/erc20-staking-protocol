// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StakingPool is ReentrancyGuard, Ownable {
      using SafeERC20 for IERC20;

      IERC20 public rewardToken;           // The token being staked and  ewarded

      uint256 public rewardRate;           // Tokens per second
      uint256 public rewardsDuration = 30 days;  // Reward period
      uint256 public periodFinish;         // When rewards end
      uint256 public lastUpdateTime;       // Last reward update
      uint256 public rewardPerTokenStored; // Accumulated reward per token

      uint256 private _totalSupply;        // Total staked

      // Mappings for user data
      mapping(address => uint256) private _balances;
      mapping(address => uint256) public userRewardPerTokenPaid;
      mapping(address => uint256) public rewards;

      // Events (for tracking on blockchain)
      event Staked(address indexed user, uint256 amount);
      event Withdrawn(address indexed user, uint256 amount);
      event RewardPaid(address indexed user, uint256 reward);
      event RewardAdded(uint256 reward);
      event EmergencyWithdraw(address indexed user, uint256 amount);

      // Constructor
      constructor(address _rewardToken) Ownable(msg.sender) {
          rewardToken = IERC20(_rewardToken);
      }

      // View functions

      function totalSupply() external view returns (uint256) {
          return _totalSupply;
      }

      function balanceOf(address account) external view returns (uint256) {
          return _balances[account];
      }

      // Calculate accumulated reward per token
      function rewardPerToken() public view returns (uint256) {
          if (_totalSupply == 0) {
              return rewardPerTokenStored;
          }

          return rewardPerTokenStored +
              ((lastTimeApplicable() - lastUpdateTime) * rewardRate * 1e18 / _totalSupply);
      }

      // Get the latest applicable time (current time or period end)
      function lastTimeApplicable() public view returns (uint256) {
          return block.timestamp < periodFinish ? block.timestamp : periodFinish;
      }

      // Calculate earned rewards for an account
      function earned(address account) public view returns (uint256) {
        return (_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18)
             + rewards[account];
      }

      // Get staking info for an account
      function getStakeInfo(address account) external view returns (
        uint256 stakedBalance,
        uint256 earnedRewards,
        uint256 rewardRatePerSecond,
        uint256 periodEnd
      ) {
        return (
          _balances[account],
          earned(account),
          rewardRate,
          periodFinish
        );
      }

      // Update rewards before any action 
      modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeApplicable();

        if (account != address(0)) {
          rewards[account] = earned(account);
          userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }_;
      }

      // Stake tokens to earn rewards
      function stake(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
      {
        require(amount > 0, "Cannot stake 0");

        _totalSupply += amount;
        _balances[msg.sender] += amount;

        rewardToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
      }

      // Withdraw staked tokens
      function withdraw(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
      {
        require(amount > 0, "Cannot withdraw 0");
        require(_balances[msg.sender] >= amount, "Insufficient staked balance");

        _totalSupply -= amount;
        _balances[msg.sender] -= amount;

        rewardToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
      }

      // Claim accumulated rewards
      function getReward()
        external
        nonReentrant
        updateReward(msg.sender)
      {
        uint256 reward = rewards[msg.sender];

        if (reward > 0) {
          rewards[msg.sender] = 0;
          rewardToken.safeTransfer(msg.sender, reward);
          emit RewardPaid(msg.sender, reward);
        }
      }

      // Owner adds rewards to the pool
      function notifyRewardAmount(uint256 reward)
        external
        onlyOwner
        updateReward(address(0))
      {
        if (block.timestamp < periodFinish) {
          uint256 remaining = periodFinish - block.timestamp;
          uint256 leftover = remaining * rewardRate;
          rewardRate = (reward + leftover) / rewardsDuration;
        } else {
          rewardRate = reward / rewardsDuration;
        }

        require(rewardRate > 0, "Reward rate = 0");
        require(
          rewardRate * rewardsDuration <= rewardToken.balanceOf(address(this)),
          "Insufficient reward balance"
        );

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        emit RewardAdded(reward);
      }

      // Emergency withdraw: exit without claiming rewards
      function emergencyWithdraw() external nonReentrant {
        uint256 balance = _balances[msg.sender];
        require(balance > 0, "No staked balance");

        _totalSupply -= balance;
        _balances[msg.sender] = 0;
        rewards[msg.sender] = 0;

        rewardToken.safeTransfer(msg.sender, balance);

        emit EmergencyWithdraw(msg.sender, balance);
      }

      // Owner can recover wrong tokens sent to contract
      function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        onlyOwner
      {
        require(tokenAddress != address(rewardToken), "Cannot withdraw staking token");
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
      }
  }

