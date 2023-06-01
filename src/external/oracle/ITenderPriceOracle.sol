// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

interface TenderPriceOracle {
  function decimals(address token) external view returns (uint8);
  function latestRoundData(address token) external view returns (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  );

  function getOracleDecimals(address token) external view returns (uint);
  function getUSDPrice(address token) external view returns (uint);

  function getUnderlyingDecimals(address ctoken) external view returns (uint);
  function getUnderlyingPrice(address ctoken) external view returns (uint);
}
