# DeFi Staking Pool

A simple time-based staking contract built with Solidity and Foundry. Users can stake ERC20 tokens and earn rewards proportional to their stake over a defined period.

## Overview

This project includes two main contracts:

- **RewardToken**: A standard ERC20 token with mint/burn functionality
- **StakingPool**: A staking contract that distributes rewards to stakers over time

The staking pool implements the Synthetix staking rewards model, which uses a reward-per-token calculation to ensure fair distribution based on both stake amount and duration. Rewards are distributed continuously over a 30-day period (configurable).

## Setup

Install dependencies:

```bash
forge install
```

Copy the example environment file and add your private key:

```bash
cp .example.env .env
```

## Testing

Run tests:

```bash
forge test
```

For gas reporting:

```bash
forge test -vv
```

Run specific tests:

```bash
forge test --match-contract StakingPoolTest
forge test --match-test testStake
```

## Deployment

Deploy to Sepolia testnet:

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast -vvvv
```

The deploy script will:
1. Deploy the RewardToken with an initial supply
2. Deploy the StakingPool contract
3. Log both contract addresses

## Contract Architecture

### RewardToken
Standard ERC20 with:
- Owner-controlled minting
- Public burn function
- Initial supply minted to deployer

### StakingPool
Features:
- Stake tokens to earn rewards
- Withdraw staked tokens at any time
- Claim accumulated rewards
- Emergency withdraw (forfeit rewards)
- Owner can add rewards to extend/refresh the reward period

The pool tracks `rewardPerToken` which increases based on time elapsed and total staked amount. Each user's rewards are calculated by multiplying their stake by the difference between current and their last recorded `rewardPerToken`. This allows for efficient reward calculation without iterating through all stakers.

## Usage Example

```solidity
// Stake tokens
token.approve(address(stakingPool), amount);
stakingPool.stake(amount);

// Check earned rewards
uint256 earned = stakingPool.earned(userAddress);

// Claim rewards
stakingPool.getReward();

// Withdraw stake
stakingPool.withdraw(amount);
```

## Security

- Uses OpenZeppelin's ReentrancyGuard for state-changing functions
- SafeERC20 for all token transfers
- Owner-only functions for privileged operations
- Emergency withdraw function for users in case of issues

## License

MIT

