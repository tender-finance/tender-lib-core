// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

interface UniswapV3Pair {
  function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool);
  function token0() external view returns (address);
  function token1() external view returns (address);
}
