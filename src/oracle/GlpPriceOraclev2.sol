// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import {SafeMath} from "oz/utils/math/SafeMath.sol";
import {IERC20Metadata as IERC20} from "oz/interfaces/IERC20Metadata.sol";
import {IGlpManager} from "../external/gmx/IGlpManager.sol";
import {IGmxVault} from "../external/gmx/IGmxVault.sol";
import {IChainlinkPriceOracle} from "../external/oracle/IChainlinkPriceOracle.sol";
import {TenderPriceOracle} from "./TenderPriceOracle.sol";
import {ICToken} from "../external/compound/ICToken.sol";
import {console} from "forge-std/console.sol";

interface GMXRouter{
  struct CreateDepositParams {
    address receiver;
    address callbackContract;
    address uiFeeReceiver;
    address market;
    address initialLongToken;
    address initialShortToken;
    address[] longTokenSwapPath;
    address[] shortTokenSwapPath;
    uint256 minMarketTokens;
    bool shouldUnwrapNativeToken;
    uint256 executionFee;
    uint256 callbackGasLimit;
  }
  struct CreateWithdrawalParams {
    address receiver;
    address callbackContract;
    address uiFeeReceiver;
    address market;
    address[] longTokenSwapPath;
    address[] shortTokenSwapPath;
    uint256 minLongTokenAmount;
    uint256 minShortTokenAmount;
    bool shouldUnwrapNativeToken;
    uint256 executionFee;
    uint256 callbackGasLimit;
  }
  function dataStore() external view returns (address);
  function depositHandler() external view returns (address);
  function withdrawalHandler() external view returns (address);
  function createDeposit(
    GMXRouter.CreateDepositParams calldata params
  ) external payable returns (bytes32); // Returns unique key for deposit
  function createWithdrawal(
    GMXRouter.CreateWithdrawalParams calldata params
  ) external payable returns (bytes32); // Returns unique key for deposit
  function cancelDeposit(bytes32 key) external payable;
  function cancelWithdrawal(bytes32 key) external payable;
}


interface GMXReader {
  struct MarketProps {
    address marketToken;
    address indexToken;
    address longToken;
    address shortToken;
  }
  struct PriceProps {
    uint256 min;
    uint256 max;
  }
  struct MarketPoolValueInfoProps {
    int256 poolValue;
    int256 longPnl;
    int256 shortPnl;
    int256 netPnl;

    uint256 longTokenAmount;
    uint256 shortTokenAmount;
    uint256 longTokenUsd;
    uint256 shortTokenUsd;

    uint256 totalBorrowingFees;
    uint256 borrowingFeePoolFactor;

    uint256 impactPoolAmount;
  }
  struct MarketPrices {
    GMXReader.PriceProps indexTokenPrice;
    GMXReader.PriceProps longTokenPrice;
    GMXReader.PriceProps shortTokenPrice;
  }
  function getMarketTokenPrice(
    address dataStore,
    GMXReader.MarketProps calldata market,
    GMXReader.PriceProps calldata indexTokenPrice,
    GMXReader.PriceProps calldata longTokenPrice,
    GMXReader.PriceProps calldata shortTokenPrice,
    bytes32 pnlFactorType,
    bool maximize
  ) external view returns (int256, GMXReader.MarketPoolValueInfoProps memory);
  function getWithdrawalAmountOut(
    address dataStore,
    GMXReader.MarketProps calldata market,
    GMXReader.MarketPrices calldata prices,
    uint256 marketTokenAmount,
    address uiFeeReceiver
  ) external view returns (uint256, uint256);
  function getMarket(address dataStore, address gmAddress) external view returns (GMXReader.MarketProps memory);
}

interface WETH {
  function deposit() external payable;
  function withdraw(uint256 amount) external;
}

interface DataStore{
  function getUint(bytes32 key) external view returns (uint256);
}

contract GlpPriceOraclev2 is IChainlinkPriceOracle {
  using SafeMath for uint256;

  address constant _GMX_EXCHANGE_ROUTER = address(0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8);
  address constant _GMX_EXCHANGE_READER = address(0x60a0fF4cDaF0f6D496d71e0bC0fFa86FE8E6B23c);
  TenderPriceOracle _tenderOracle = TenderPriceOracle(0x0c261270eD2E036c9525243E5Dd0e95f824D77d2);
  IERC20 public immutable glpToken = IERC20(0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258);
  IGlpManager public immutable glpManager = IGlpManager(0x321F653eED006AD1C29D174e17d96351BDe22649);
  IGmxVault public glpVault = IGmxVault(0x489ee077994B6658eAfA855C308275EAd8097C4A);

  address public marketToken = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;

  ICToken public tContract;
  ICToken constant public tUSDC_CONTRACT = ICToken(0x068485a0f964B4c3D395059a19A05a8741c48B4E);

  constructor(ICToken _tContract) public {
    tContract = _tContract;
  }

  function getVaultPercentageCurrent(address token) public view returns (uint256) {
    return glpVault.usdgAmounts(token).mul(1e18).div(getGlpAum(true));
  }

  function getGlpSupply() public view returns (uint256) {
    return glpToken.totalSupply();
  }

  function getGlpAum(bool maximize) public view returns (uint256) {
    return glpManager.getAumInUsdg(maximize);
  }

  function getGlpPrice() public view returns (int256) {
    return int256(getGlpAum(false).mul(1e18).div(getGlpSupply()));
  }

  function decimals() public pure returns (uint8) {
    return 18;
  }

  function latestRoundData()
    public
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return (0, int256(getGMTokenPrice()), 0, 0, 0);
  }

  function _getNormalizedTokenPrice(ICToken tContract) internal view returns (uint256) {
    uint256 underlyingDecimals =  _tenderOracle.getUnderlyingDecimals(tContract); // ETH = 18, USDC = 6
    uint256 _latestPrice = _tenderOracle.getUSDPrice(tContract.underlying()); // always 8 decimals
    return _latestPrice.mul(1e22).div(10**underlyingDecimals); // expected 30 decimals
  }

  // NOTE: _getGMTokenPrice is locked to the markets defined in the contract
  function getGMTokenPrice() public view returns (uint256) {
    address datastoreAddress = GMXRouter(_GMX_EXCHANGE_ROUTER).dataStore();
    GMXReader reader = GMXReader(_GMX_EXCHANGE_READER);
    GMXReader.MarketProps memory _marketProp = reader.getMarket(datastoreAddress, marketToken);
    bytes32 pnlFactor = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_WITHDRAWALS")); // Use this pnl cap for all token price calculations

    GMXReader.PriceProps memory longPrice;
    {
      uint256 price = _getNormalizedTokenPrice(tContract);
      longPrice.max = price;
      longPrice.min = price;
      console.log("Price1: ", price);
    }

    GMXReader.PriceProps memory shortPrice;
    {
      uint256 price = _getNormalizedTokenPrice(tUSDC_CONTRACT);
      shortPrice.max = price;
      shortPrice.min = price;
      console.log("Price2: ", price);
    }

    (int256 price, ) = reader.getMarketTokenPrice(datastoreAddress, _marketProp, longPrice, longPrice, shortPrice, pnlFactor, true); // returning 8 decimals
    console.log("Price: ", uint256(price));
    console.log("=============");

    if(price < 0){
      return 0;
    }else{
      return uint256(price).div(1e8);
    }
  }
}
