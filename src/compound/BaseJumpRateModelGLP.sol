// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./InterestRateModel.sol";
import {console2 as console} from 'forge-std/console2.sol';

interface GlpManager{
  function getAumInUsdg(bool maximise) external view returns (uint256);
}

interface ITenderPriceOracle {
  function getOracleDecimals(address token) external view returns (uint256);
  function getUSDPrice(address token) external view returns (uint256);

  function getUnderlyingDecimals(address ctoken) external view returns (uint256);
  function getUnderlyingPrice(address ctoken) external view returns (uint256);

  function setOracle(address token, address oracle) external;
}

interface IRewardDistributor {
    function rewardToken() external view returns (address);
    function tokensPerInterval() external view returns (uint256);
    function pendingRewards() external view returns (uint256);
    function distribute() external returns (uint256);
}

/**
  * @title Logic for Compound's JumpRateModel Contract V2.
  * @author Compound (modified by Dharma Labs, refactored by Arr00)
  * @notice Version 2 modifies Version 1 by enabling updateable parameters.
  */
abstract contract BaseJumpRateModelGLP is InterestRateModel {
    event NewInterestParams(uint baseRatePerBlock, uint multiplierPerBlock, uint jumpMultiplierPerBlock, uint kink);

    uint256 private constant BASE = 1e18;

    /**
     * @notice The address of the owner, i.e. the Timelock contract, which can update parameters directly
     */
    address public owner;

    /**
     * @notice The approximate number of blocks per year that is assumed by the interest rate model
     */
    uint public constant blocksPerYear = 2628000;

    /**
     * @notice The multiplier of utilization rate that gives the slope of the interest rate
     */
    uint public multiplierPerBlock;

    /**
     * @notice The base interest rate which is the y-intercept when utilization rate is 0
     */
    uint public baseRatePerBlock;

    /**
     * @notice The multiplierPerBlock after hitting a specified utilization point
     */
    uint public jumpMultiplierPerBlock;

    /**
     * @notice The utilization point at which the jump multiplier is applied
     */
    uint public kink;

    bool dynamicRates = true;

    IRewardDistributor public glpDistributor = IRewardDistributor(0x5C04a12EB54A093c396f61355c6dA0B15890150d);
    address public fsGlp = address(0x1aDDD80E6039594eE970E5872D247bf0414C8903);
    address public wEth = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    GlpManager public glpManager = GlpManager(0x321F653eED006AD1C29D174e17d96351BDe22649);

    //store gmx price for slippage calculation
    ITenderPriceOracle tndOracle = ITenderPriceOracle(0x0c261270eD2E036c9525243E5Dd0e95f824D77d2);

    constructor(
    uint256 baseRatePerYear,
    uint256 multiplierPerYear,
    uint256 jumpMultiplierPerYear,
    uint256 kink_,
    address owner_
  ) internal {
    owner = owner_;

    updateJumpRateModelInternal(baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink_);
  }

  /**
   * @notice Update the parameters of the interest rate model (only callable by owner, i.e. Timelock)
   * @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by BASE)
   * @param multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by BASE)
   * @param jumpMultiplierPerYear The multiplierPerBlock after hitting a specified utilization point
   * @param kink_ The utilization point at which the jump multiplier is applied
   */
  function updateJumpRateModel(
    uint256 baseRatePerYear,
    uint256 multiplierPerYear,
    uint256 jumpMultiplierPerYear,
    uint256 kink_
  ) external virtual {
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
        if (borrows == 0) {
            return 0;
        }

        return borrows * BASE / (cash + borrows - reserves);
    }
    function getEthPerInterval() public view returns(uint){
        return glpDistributor.tokensPerInterval();
    }
    
    function getEthPrice() public view returns (uint){
        return tndOracle.getUSDPrice(wEth);
    }

    function getGlpPrice() public view returns (uint){
        return tndOracle.getUSDPrice(fsGlp);
    }

    function getGlpAmountTokenPerInterval() public view returns (uint){ 
        return (getEthPerInterval() * getEthPrice()) / getGlpPrice();
    }

    function getGlpAmountTokenPerInterval_() public view returns (uint){ 
        return (getEthPerInterval() * getEthPrice()) / getGlpPrice();
    }

    function getGlpAum() public view returns (uint) {
        return glpManager.getAumInUsdg(true);
    }

    function getEthPerYear() public view returns (uint256) {
        return getEthPerInterval() * blocksPerYear;
    }
    
    function getGlpApy() public view returns (uint){ 
        return (getEthPerYear() * getEthPrice()) / getGlpAum();
    }

    function getBaseRatePerBlock() public view returns(uint){
        return (getGlpApy() / 2) - (getGlpApy() / 10);
    }
    
    function getMultiplierPreKink() public view returns(uint){
        return (getGlpApy() / 2) + (getGlpApy() / 10);
    }

    function getMultiplierPostKink(uint _excessUtil) public view returns(uint){
        return (getGlpApy()) + (getGlpApy() * _excessUtil / 1000 * 1250);
    }

    function getJumpMultiplierPerBlock(uint _excessUtil) public view returns(uint){
        return ((getMultiplierPostKink(_excessUtil) - getMultiplierPreKink())/(100 - kink)) * 100;
    }

    function setKink(uint _kink) external {
        require(msg.sender == owner, "only the owner may call this function.");
        kink = _kink;
    }

    function setGlpDistributor(IRewardDistributor _glpDistributor) external {
        require(msg.sender == owner, "only the owner may call this function.");
        glpDistributor = _glpDistributor;
    }

    function setGlpManager(GlpManager _glpManager){
        require(msg.sender == owner, "only the owner may call this function.");
        glpManager = _glpManager;
    }

    function setDynamicRates(bool _dynamicRates) external{
        require(msg.sender == owner, "only the owner may call this function.");
        dynamicRates = _dynamicRates;
    }

    /**
     * @notice Calculates the current borrow rate per block, with the error code expected by the market
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @return The borrow rate percentage per block as a mantissa (scaled by BASE)
     */
    function getBorrowRateInternal(uint cash, uint borrows, uint reserves) internal view returns (uint) {
        uint util = utilizationRate(cash, borrows, reserves);
        
        if(dynamicRates){

            if (util <= kink) {
                return ((util * getMultiplierPreKink()) / BASE) + getBaseRatePerBlock();
            } else {
                uint normalRate = ((kink * getMultiplierPreKink()) / BASE) + getBaseRatePerBlock();
                uint excessUtil = util - kink;
                return ((excessUtil * getJumpMultiplierPerBlock(excessUtil)) / BASE) + normalRate;
            }
        } else {

            if (util <= kink) {
            return ((util * multiplierPerBlock) / BASE) + baseRatePerBlock;
            } else {
            uint256 normalRate = ((kink * multiplierPerBlock) / BASE) + baseRatePerBlock;
            uint256 excessUtil = util - kink;
            return ((excessUtil * jumpMultiplierPerBlock) / BASE) + normalRate;
            }
        }

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
        uint oneMinusReserveFactor = BASE - reserveFactorMantissa;
        uint borrowRate = getBorrowRateInternal(cash, borrows, reserves);
        uint rateToPool = borrowRate * oneMinusReserveFactor / BASE;
        return utilizationRate(cash, borrows, reserves) * rateToPool / BASE;
    }

  /**
   * @notice Internal function to update the parameters of the interest rate model
   * @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by BASE)
   * @param multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by BASE)
   * @param jumpMultiplierPerYear The multiplierPerBlock after hitting a specified utilization point
   * @param kink_ The utilization point at which the jump multiplier is applied
   */
  function updateJumpRateModelInternal(
    uint256 baseRatePerYear,
    uint256 multiplierPerYear,
    uint256 jumpMultiplierPerYear,
    uint256 kink_
  ) internal {
    baseRatePerBlock = baseRatePerYear / blocksPerYear;
    multiplierPerBlock = (multiplierPerYear * BASE) / (blocksPerYear * kink_);
    jumpMultiplierPerBlock = jumpMultiplierPerYear / blocksPerYear;
    kink = kink_;

    emit NewInterestParams(baseRatePerBlock, multiplierPerBlock, jumpMultiplierPerBlock, kink);
  }
}
