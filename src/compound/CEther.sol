// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.10;

import {ComptrollerInterface} from "./ComptrollerInterface.sol";
import {InterestRateModel} from "./InterestRateModel.sol";
import {CToken} from "./CToken.sol";

/**
 * @title Compound's CEther Contract
 * @notice CToken which wraps Ether
 * @author Compound
 */
contract CEther is CToken {
  /**
   * @notice Construct a new CEther money market
   * @param comptroller_ The address of the Comptroller
   * @param interestRateModel_ The address of the interest rate model
   * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
   * @param name_ ERC-20 name of this token
   * @param symbol_ ERC-20 symbol of this token
   * @param decimals_ ERC-20 decimal precision of this token
   * @param admin_ Address of the administrator of this token
   * @param isGLP_ Wether or not the market being created is for the GLP token
   */
  constructor(
    ComptrollerInterface comptroller_,
    InterestRateModel interestRateModel_,
    uint256 initialExchangeRateMantissa_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address payable admin_,
    bool isGLP_
  ) {
    // Creator of the contract is admin during initialization
    admin = payable(msg.sender);

    initialize(comptroller_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_, isGLP_);

    // Set the proper admin now that initialization is done
    admin = admin_;
  }

  /**
   * User Interface **
   */

  /**
   * @notice Sender supplies assets into the market and receives cTokens in exchange
   * @dev Reverts upon any failure
   */
  function mint() external payable returns (uint256) {
    mintInternal(msg.value);
    comptroller.addToMarketExternal(address(this), msg.sender);
    return NO_ERROR;
  }

  /**
   * @notice Sender redeems cTokens in exchange for the underlying asset
   * @dev Accrues interest whether or not the operation succeeds, unless reverted
   * @param redeemTokens The number of cTokens to redeem into underlying
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function redeem(uint256 redeemTokens) external returns (uint256) {
    redeemInternal(redeemTokens);
    return NO_ERROR;
  }

  /**
   * @notice Sender redeems cTokens in exchange for a specified amount of underlying asset
   * @dev Accrues interest whether or not the operation succeeds, unless reverted
   * @param redeemAmount The amount of underlying to redeem
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function redeemUnderlying(uint256 redeemAmount) external returns (uint256) {
    redeemUnderlyingInternal(redeemAmount);
    return NO_ERROR;
  }

  /**
   * @notice Sender borrows assets from the protocol to their own address
   * @param borrowAmount The amount of the underlying asset to borrow
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function borrow(uint256 borrowAmount) external returns (uint256) {
    borrowInternal(borrowAmount);
    return NO_ERROR;
  }

  /**
   * @notice Sender repays their own borrow
   * @dev Reverts upon any failure
   */
  function repayBorrow() external payable returns (uint256) {
    repayBorrowInternal(msg.value);
    return NO_ERROR;
  }

  /**
   * @notice Sender repays a borrow belonging to borrower
   * @dev Reverts upon any failure
   * @param borrower the account with the debt being payed off
   */
  function repayBorrowBehalf(address borrower) external payable returns (uint256) {
    repayBorrowBehalfInternal(borrower, msg.value);
    return NO_ERROR;
  }

  /**
   * @notice The sender liquidates the borrowers collateral.
   *  The collateral seized is transferred to the liquidator.
   * @dev Reverts upon any failure
   * @param borrower The borrower of this cToken to be liquidated
   * @param cTokenCollateral The market in which to seize collateral from the borrower
   */
  function liquidateBorrow(address borrower, CToken cTokenCollateral) external payable returns (uint256) {
    liquidateBorrowInternal(borrower, msg.value, cTokenCollateral);
    return NO_ERROR;
  }

  /**
   * @notice The sender adds to reserves.
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _addReserves() external payable returns (uint256) {
    return _addReservesInternal(msg.value);
  }

  /**
   * @notice Send Ether to CEther to mint
   */
  receive() external payable {
    mintInternal(msg.value);
  }

  /**
   * Safe Token **
   */

  /**
   * @notice Gets balance of this contract in terms of Ether, before this message
   * @dev This excludes the value of the current message, if any
   * @return The quantity of Ether owned by this contract
   */
  function getCashPrior() internal view override returns (uint256) {
    return address(this).balance - msg.value;
  }

  /**
   * @notice Perform the actual transfer in, which is a no-op
   * @param from Address sending the Ether
   * @param amount Amount of Ether being sent
   * @return The actual amount of Ether transferred
   */
  function doTransferIn(address from, uint256 amount) internal override returns (uint256) {
    // Sanity checks
    require(msg.sender == from, "sender mismatch");
    require(msg.value == amount, "value mismatch");
    return amount;
  }

  function doTransferOut(address payable to, uint256 amount) internal virtual override {
    /* Send the Ether, with minimal gas and revert on failure */
    to.transfer(amount);
  }
}
