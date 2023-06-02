// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

import {IComptroller} from '../src/external/compound/Comptroller.sol';
import {ICToken} from '../src/external/compound/ICToken.sol';
import {Addresses} from '../script/shared/Addresses.sol';
import {ITenderPriceOracle} from "../src/external/oracle/ITenderPriceOracle.sol";
import {GlpPriceOracle} from '../src/oracle/GlpPriceOracle.sol';
import {IERC20Metadata as IERC20} from "oz/interfaces/IERC20Metadata.sol";
import {GMDPriceFeedFactory} from '../src/oracle/GMDPriceOracle.sol';
import {DeployOracle} from '../script/deploy/DeployOracle.sol';
import {Test} from 'forge-std/Test.sol';

contract TestOracle is Test {
  IComptroller comptroller = IComptroller(Addresses.unitroller);
  address owner = Addresses.multisig;
  address admin = Addresses.admin;
  ITenderPriceOracle oracle;

  address[] public markets = [
    0x0706905b2b21574DEFcF00B5fc48068995FCdCdf,
    0x0A2f8B6223EB7DE26c810932CCA488A4936cF391,
    0x87D06b55e122a0d0217d9a4f85E983AC3d7a1C35,
    0x8b44D3D286C64C8aAA5d445cFAbF7a6F4e2B3A71,
    0x068485a0f964B4c3D395059a19A05a8741c48B4E,
    0x4A5806A3c4fBB32F027240F80B18b26E40BF7E31,
    0xB287180147EF1A97cbfb07e2F1788B75df2f6299,
    0x27846A0f11EDC3D59EA227bAeBdFa1330a69B9ab,
    0x20a6768F6AABF66B787985EC6CE0EBEa6D7Ad497,
    0xFF2073D3810754D6da4783235c8647e11e43C943,
    0xC6121d58E01B3F5C88EB8a661770DB0046523539,
    0x4180f39294c94F046362c2DBC89f2DF7786842c3,
    0x242f91207184FCc220beA3c9E5f22b6d80F3faC5,
    0xB5dBDb01B08bff12E822EB28259ECCEb6cC91529,
    0xB60EF53BA18Bd85Ab642c2F78dF13e7aBCCdCb9c,
    0xe4843e44342617024F6b9d615dFfBe8858F8Ea16,
    0x80aEFB7dAde25542cc2f558Ee605aC2FC974Ceb9
  ];


  function setUp() public {
    vm.deal(admin, 1 ether);
    vm.startPrank(admin, admin);
    oracle = DeployOracle.deploy();
    vm.stopPrank();
  }

  function testPrices() public {
    address[] memory _markets = markets;
    ITenderPriceOracle oldOracle = ITenderPriceOracle(comptroller.oracle());

    for(uint i=0; i < _markets.length; i++) {
      ICToken cToken = ICToken(_markets[i]);
      uint newPrice = oracle.getUnderlyingPrice(cToken);
      uint oldPrice = oldOracle.getUnderlyingPrice(cToken);

      (uint lower, uint higher) = (newPrice <= oldPrice) ? (newPrice, oldPrice) : (oldPrice, newPrice);
      uint percentSimilar = (lower * 100)/higher;
      // require less than 1% deviation
      assertGe(percentSimilar, 99);
    }
  }
}
