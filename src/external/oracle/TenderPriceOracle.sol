// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

interface ChainLinkPriceOracle {
  function latestAnswer() external view returns (uint256);
  function decimals() external view returns (uint8);
}

interface ITenderPriceOracle {
  function addVaultToken(address vaultToken_) external;
  function getGlpSupply() external view returns (uint256);
  function getGlpAum() external view returns (uint256);
  function getGlpPrice() external view returns (uint256);
  function getUSDPrice(address token) external view returns (uint);
  function getOracleDecimals(address token) external view returns (uint);
  function isVaultToken(address ctoken) external view returns (bool);
  function getVaultLeverage(address ctoken) external view returns (uint);
  function getUnderlyingDecimals(address ctoken) external view returns (uint);
  function getUnderlyingPrice(address ctoken) external view returns (uint);
}
