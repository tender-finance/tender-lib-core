// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import {SafeMath} from 'oz/utils/math/SafeMath.sol';
import {IERC20Metadata as IERC20} from "oz/interfaces/IERC20Metadata.sol";
import {IGlpManager} from '../external/gmx/IGlpManager.sol';
import {IGmxVault} from '../external/gmx/IGmxVault.sol';
import {IChainlinkPriceOracle} from '../external/oracle/IChainlinkPriceOracle.sol';

contract GlpPriceOracle is IChainlinkPriceOracle {
  using SafeMath for uint256;

  IERC20 public immutable glpToken = IERC20(0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258);
  IGlpManager public immutable glpManager = IGlpManager(0x321F653eED006AD1C29D174e17d96351BDe22649);
  IGmxVault public glpVault = IGmxVault(0x489ee077994B6658eAfA855C308275EAd8097C4A);

  function getVaultPercentageCurrent(address token) public view returns (uint){
    return glpVault.usdgAmounts(token).mul(1e18).div(getGlpAum(true));
  }

  function getGlpSupply() public view returns (uint) {
    return glpToken.totalSupply();
  }

  function getGlpAum(bool maximize) public view returns (uint) {
    return glpManager.getAumInUsdg(maximize);
  }

  function getGlpPrice() public view returns (int) {
    return int(getGlpAum(false).mul(1e8).div(getGlpSupply()));
  }

  function decimals() public pure returns (uint8) {
    return 8;
  }

  function latestRoundData() public view returns (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  ) {
    return (0, getGlpPrice(), 0, 0, 0);
  }
}
