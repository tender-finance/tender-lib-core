// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import {SafeMath} from 'oz/utils/math/SafeMath.sol';
import {IERC20Metadata as IERC20} from "oz/interfaces/IERC20Metadata.sol";
import {IChainlinkPriceOracle} from '../external/oracle/IChainlinkPriceOracle.sol';

interface IGMDVault {
  function GDpriceToStakedtoken (uint id) external view returns (uint);
}

interface IGMDPriceFeed {
  function latestAnswer() external view returns (uint256);
  function decimals() external view returns (uint8);
}

contract GMDPriceFeedFactory {
  mapping(uint => address) public idAssets;
  mapping(address => uint) public assetIds;
  mapping(uint => IChainlinkPriceOracle) underlyingOracles;
  mapping(IERC20 => IERC20) underlyings;
  mapping(address => GMDPriceFeed) public gmdPriceFeeds; 
  IGMDVault public gmdVault = IGMDVault(0x8080B5cE6dfb49a6B86370d6982B3e2A86FBBb08);

  constructor() {
    idAssets[0] = 0x3DB4B7DA67dd5aF61Cb9b3C70501B1BdB24b2C22; // gmdUSDC
    idAssets[1] = 0x1E95A37Be8A17328fbf4b25b9ce3cE81e271BeB3; // gmdETH
    idAssets[2] = 0x147FF11D9B9Ae284c271B2fAaE7068f4CA9BB619; // gmdBTC
    idAssets[4] = 0x34101Fe647ba02238256b5C5A58AeAa2e532A049; // gmdUSDT

    assetIds[0x3DB4B7DA67dd5aF61Cb9b3C70501B1BdB24b2C22] = 0; // gmdUSDC
    assetIds[0x1E95A37Be8A17328fbf4b25b9ce3cE81e271BeB3] = 1; // gmdETH
    assetIds[0x147FF11D9B9Ae284c271B2fAaE7068f4CA9BB619] = 2; // gmdBTC
    assetIds[0x34101Fe647ba02238256b5C5A58AeAa2e532A049] = 4; // gmdUSDT

    underlyingOracles[0] = IChainlinkPriceOracle(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3); // gmdUSDC
    underlyingOracles[1] = IChainlinkPriceOracle(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612);
    underlyingOracles[2] = IChainlinkPriceOracle(0x6ce185860a4963106506C203335A2910413708e9);
    underlyingOracles[4] = IChainlinkPriceOracle(0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7);

    for(uint i = 0; i < 5; i++) {
      if (idAssets[i] != address(0)) {
        GMDPriceFeed gmdPriceFeed = new GMDPriceFeed(gmdVault, i, IERC20(idAssets[i]), underlyingOracles[i]);
        gmdPriceFeeds[idAssets[i]] = gmdPriceFeed; 
      }
    }
  }
  function getGMDPriceFeed(address _asset) public view returns (GMDPriceFeed) {
    return gmdPriceFeeds[_asset];
  }
}

contract GMDPriceFeed is IChainlinkPriceOracle {
  using SafeMath for uint;
  IGMDVault public gmdVault;
  IERC20 public gmdTokenAddr;
  IERC20 public underlyingAddress;
  IChainlinkPriceOracle public underlyingOracle;
  uint public gmdTokenId;

  constructor(
    IGMDVault _gmdVault,
    uint _gmdTokenId,
    IERC20 _gmdTokenAddr,
    IChainlinkPriceOracle _underlyingOracle
  ) {
    gmdVault = _gmdVault;
    gmdTokenId = _gmdTokenId;
    gmdTokenAddr = _gmdTokenAddr;
    underlyingOracle = _underlyingOracle;
  }

  function latestRoundData() public view returns (uint80, int256, uint256, uint256, uint80) {
    uint priceInUnderlying = gmdVault.GDpriceToStakedtoken(gmdTokenId);
    (, int _answer, , ,) = underlyingOracle.latestRoundData();
    require(_answer > 0, 'Oracle Error');
    int answer = int(priceInUnderlying.mul(uint(_answer)).div(10**underlyingOracle.decimals()));
    return (0, int(answer), 0, 0, 0);
  }

  function decimals() public pure returns (uint8) {
    return 18;
  }

  function token() public view returns (IERC20) {
    return gmdTokenAddr;
  }
}
