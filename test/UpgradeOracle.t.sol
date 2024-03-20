// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import {DeployGlpWETHOracle} from "../script/deploy/DeployGlpWETHOracle.sol";
import {Addresses} from "../script/shared/Addresses.sol";
import {ITenderPriceOracle} from "../src/external/oracle/ITenderPriceOracle.sol";
import {GlpPriceOraclev2} from "../src/oracle/GlpPriceOraclev2.sol";
import {ICToken} from "../src/external/compound/ICToken.sol";
import {SafeMath} from "oz/utils/math/SafeMath.sol";

contract TestUpgradeOracle is Test {
  using SafeMath for uint256;

	address admin = Addresses.admin;
	ITenderPriceOracle tOracle;

	function setUp() public {
		vm.deal(admin, 1 ether);
		vm.startPrank(admin);
		tOracle = ITenderPriceOracle(Addresses.oracle);
		vm.stopPrank();
	}

	function test_Pass() public {
		GlpPriceOraclev2 oracle = DeployGlpWETHOracle.deploy();
		uint256 price = oracle.getGMTokenPrice();
		console.log("WETH Ticker: ", price);
		uint256 usdtPrice = tOracle.getUnderlyingPrice(ICToken(Addresses.tUSDC));
		console.log("USDC Ticker: ", usdtPrice.mul(11).div(10));
		console.log("USDC Ticker: ", usdtPrice);
	}
}
