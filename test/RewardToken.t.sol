pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RewardToken} from "../src/RewardToken.sol";

contract RewardTokenTest is Test {
  RewardToken public token;
  address public owner;
  address public max;
  address public tom;

  uint256 constant INITIAL_SUPPLY = 1000000 * 10**18; // 1 million
  uint256 constant TO_MINT = 500000;

  function setUp() public {
    owner = address(this);
    max = address(0x1);
    tom = address(0x2);

    token = new RewardToken("Dirt Coin", "DIRT", INITIAL_SUPPLY);

  }
  
  function test_InitialSupply() public {
    assertEq(token.totalSupply(), INITIAL_SUPPLY);
  }

  function test_OwnerHasInitialTokens() public {
    assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
  }

  function test_OwnerCanMint() public {
    token.mint(max, TO_MINT);

    assertEq(token.balanceOf(max),TO_MINT);
  }
  

}
