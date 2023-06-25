// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.10;

import {BaseJumpRateModelGLP} from "./BaseJumpRateModelGLP.sol";
import {InterestRateModel} from "./InterestRateModel.sol";

/**
 * @title Compound's JumpRateModel Contract V2 for V2 cTokens
 * @author Arr00
 * @notice Supports only for V2 cTokens
 */
contract JumpRateModelGLP is InterestRateModel, BaseJumpRateModelGLP {
  /**
   * @notice Calculates the current borrow rate per block
   * @param cash The amount of cash in the market
   * @param borrows The amount of borrows in the market
   * @param reserves The amount of reserves in the market
   * @return The borrow rate percentage per block as a mantissa (scaled by 1e18)
   */
  function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) external view override returns (uint256) {
    return getBorrowRateInternal(cash, borrows, reserves);
  }

  constructor(
    address owner_
  ) BaseJumpRateModelGLP(owner_) {}
}
