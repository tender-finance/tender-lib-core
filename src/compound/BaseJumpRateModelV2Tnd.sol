// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./InterestRateModel.sol";
import "./../lib/interface/AggregatorInterface.sol";
import "./SafeMath.sol";

interface GMXPriceOracle {
  function getGlpSupply() external view returns (uint256);
  function getGlpAum() external view returns (uint256);
  function getAssetPrice(address asset) external view returns (uint256);
  function getGmxPrice() external view returns (uint256);
}

interface IRewardDistributor {

  function rewardToken() external view returns (address);
  function tokensPerInterval() external view returns (uint256);
  function pendingRewards() external view returns (uint256);
  function distribute() external returns (uint256);

}

interface GlpManager {
  function getAumInUsdg(bool maximise) external view returns (uint256);
}
/**
  * @title Logic for Compound's JumpRateModel Contract V2.
  * @author Compound (modified by Dharma Labs, refactored by Arr00)
* @notice Version 2 modifies Version 1 by enabling updateable parameters.
  */
abstract contract BaseJumpRateModelV2Tnd is InterestRateModel {
  using SafeMath for uint256;
  uint256 private constant BASE = 1e18;
  address public owner;
  address public glpVault = 0x489ee077994B6658eAfA855C308275EAd8097C4A;
  GlpManager glpManager = GlpManager(0x3963FfC9dff443c2A94f21b129D429891E32ec18);
  address public fsGLP = 0x1aDDD80E6039594eE970E5872D247bf0414C8903;
  address public fGLP = 0x4e971a87900b931fF39d1Aad67697F49835400b6;
  address public glp = 0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258;
  GMXPriceOracle oracle = GMXPriceOracle(0x626fEE808A206dF7529B5AB7E5a6E8FC98509cEA);
  uint public constant blocksPerYear = 2628000;
  uint public multiplierPerBlock;
  uint public baseRatePerBlock;
  uint public jumpMultiplierPerBlock;
  uint public kink;
  IRewardDistributor public glpDistributor = IRewardDistributor(0x5C04a12EB54A093c396f61355c6dA0B15890150d);
  //store glp price for slippage calculation
  AggregatorInterface wethOracleFeed = AggregatorInterface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612);

/**
  * @notice Construct an interest rate model
* @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by BASE)
* @param multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by BASE)
* @param jumpMultiplierPerYear The multiplierPerBlock after hitting a specified utilization point
* @param kink_ The utilization point at which the jump multiplier is applied
* @param owner_ The address of the owner, i.e. the Timelock contract (which has the ability to update parameters directly)
*/
constructor(uint baseRatePerYear, uint multiplierPerYear, uint jumpMultiplierPerYear, uint kink_, address owner_) internal {
    owner = owner_;

    updateJumpRateModelInternal(baseRatePerYear,  multiplierPerYear, jumpMultiplierPerYear, kink_);
  }


  function getAumInUsdg() public view returns (uint256){
    return glpManager.getAumInUsdg(true); // 428851069,305319770736134981
  }

  function getGlpPrice() public view returns (uint256){
    oracle.getGlpAum().mul(1e18).div(oracle.getGlpSupply());
  }

  /**
    * @notice Update the parameters of the interest rate model (only callable by owner, i.e. Timelock)
  * @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by BASE)
  * @param multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by BASE)
  * @param jumpMultiplierPerYear The multiplierPerBlock after hitting a specified utilization point
  * @param kink_ The utilization point at which the jump multiplier is applied
  */
  function updateJumpRateModel(uint baseRatePerYear, uint multiplierPerYear, uint jumpMultiplierPerYear, uint kink_) virtual external {
    require(msg.sender == owner, "only the owner may call this function.");

    updateJumpRateModelInternal(baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink_);
  }


  /**
    * @notice Calculates the utilization rate of the market: `borrows / (cash + borrows - reserves)`
  * @param cash The amount of cash in the market
  * @param borrows The amount of borrows in the market
  * @param reserves The amount of reserves in the market (currently unused)
  * @return The utilization rate as a mantissa between [0, BASE]
  */
  function utilizationRate(uint cash, uint borrows, uint reserves) public pure returns (uint) {
    // Utilization rate is 0 when there are no borrows
    return 0;
  }

  function getGlpAmountTokenPerInterval() internal view returns (uint){
    uint256 ethPerInterval = glpDistributor.tokensPerInterval();
    uint256 ethPrice = wethOracleFeed.latestAnswer();
    uint256 glpPrice = getGlpPrice();
    return (ethPerInterval * ethPrice) / glpPrice;
  }


  /**
    * @notice Calculates the current borrow rate per block, with the error code expected by the market
  * @param cash The amount of cash in the market
  * @param borrows The amount of borrows in the market
  * @param reserves The amount of reserves in the market
  * @return The borrow rate percentage per block as a mantissa (scaled by BASE)
  */
  function getBorrowRateInternal(uint cash, uint borrows, uint reserves) internal view returns (uint) {
    // cant borrow
    return 0;
  }



  /**
    * @notice Calculates the current supply rate per block
  * @param cash The amount of cash in the market
  * @param borrows The amount of borrows in the market
  * @param reserves The amount of reserves in the market
  * @param reserveFactorMantissa The current reserve factor for the market
    * @return The supply rate percentage per block as a mantissa (scaled by BASE)
  */
  function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) virtual override public view returns (uint) {
    uint256 SECONDS_PER_YEAR=31536000;
    return glpDistributor.tokensPerInterval().mul(SECONDS_PER_YEAR).div(oracle.getGlpSupply()).mul(30e16).div(1e18);
  }

  /**
    * @notice Internal function to update the parameters of the interest rate model
  * @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by BASE)
  * @param multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by BASE)
  * @param jumpMultiplierPerYear The multiplierPerBlock after hitting a specified utilization point
  * @param kink_ The utilization point at which the jump multiplier is applied
  */
  function updateJumpRateModelInternal(uint baseRatePerYear, uint multiplierPerYear, uint jumpMultiplierPerYear, uint kink_) internal {
    baseRatePerBlock = baseRatePerYear / blocksPerYear;
    multiplierPerBlock = (multiplierPerYear * BASE) / (blocksPerYear * kink_);
    jumpMultiplierPerBlock = jumpMultiplierPerYear / blocksPerYear;
    kink = kink_;
  }
}
