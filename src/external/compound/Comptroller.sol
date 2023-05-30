// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

interface IComptroller {
  function isComptroller () external view returns (bool);
  function oracle() external view returns (address);
  function markets(address) external view returns (
    bool isListed,
    uint collateralFactorMantissa,
    uint liquidationThresholdMantissa,
    uint collateralFactorMantissaVip,
    uint liquidationThresholdMantissaVip,
    bool isComped,
    bool isPrivate,
    bool onlyWhitelistedBorrow
  );
  function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
  function exitMarket(address cToken) external returns (uint);
  function addToMarketExternal(address cToken, address borrower) external;
  function mintAllowed(address cToken, address minter, uint mintAmount) external returns (uint);
  function mintVerify(address cToken, address minter, uint mintAmount, uint mintTokens) external;
  function redeemAllowed(address cToken, address redeemer, uint redeemTokens) external returns (uint);
  function redeemVerify(address cToken, address redeemer, uint redeemAmount, uint redeemTokens) external;
  function borrowAllowed(address cToken, address borrower, uint borrowAmount) external returns (uint);
  function borrowVerify(address cToken, address borrower, uint borrowAmount) external;
  function getIsAccountVip(address account) external view returns (bool);
  function getAllMarkets() external view returns (address[] memory);
  function getAccountLiquidity(address account, bool isLiquidationCheck) external view returns (uint, uint, uint);
  function getHypotheticalAccountLiquidity(address account, address cTokenModify, uint redeemTokens, uint borrowAmount, bool isLiquidationCheck) external view returns (uint, uint, uint);
  function _setPriceOracle(address oracle_) external;
  function _supportMarket(address delegator, bool isComped, bool isPrivate, bool onlyWhitelistedBorrow) external;
  function _setFactorsAndThresholds(address delegator, uint collateralFactor, uint collateralVIP, uint threshold, uint thresholdVIP) external;

    /// @notice Indicator that this is a Comptroller contract (for inspection)
  function repayBorrowAllowed(
    address cToken,
    address payer,
    address borrower,
    uint repayAmount
  ) external returns (uint);

  function repayBorrowVerify(
    address cToken,
    address payer,
    address borrower,
    uint repayAmount,
    uint borrowerIndex
  ) external;

  function liquidateBorrowAllowed(
    address cTokenBorrowed,
    address cTokenCollateral,
    address liquidator,
    address borrower,
    uint repayAmount
  ) external returns (uint);
  function liquidateBorrowVerify(
    address cTokenBorrowed,
    address cTokenCollateral,
    address liquidator,
    address borrower,
    uint repayAmount,
    uint seizeTokens
  ) external;

  function seizeAllowed(
    address cTokenCollateral,
    address cTokenBorrowed,
    address liquidator,
    address borrower,
    uint seizeTokens
  ) external returns (uint);

  function seizeVerify(
    address cTokenCollateral,
    address cTokenBorrowed,
    address liquidator,
    address borrower,
    uint seizeTokens
  ) external;
  function transferAllowed(
    address cToken,
    address src,
    address dst,
    uint transferTokens
  ) external returns (uint);

  function transferVerify(
    address cToken,
    address src,
    address dst,
    uint transferTokens
  ) external;

  /*** Liquidity/Liquidation Calculations ***/
  function liquidateCalculateSeizeTokens(
    address cTokenBorrowed,
    address cTokenCollateral,
    uint repayAmount
  ) external view returns (uint, uint);
}
