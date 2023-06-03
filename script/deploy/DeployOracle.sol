// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

import {IComptroller} from "../../src/external/compound/Comptroller.sol";
import {ICToken} from "../../src/external/compound/ICToken.sol";
import {Addresses} from "../shared/Addresses.sol";
import {TenderPriceOracle} from "../../src/oracle/TenderPriceOracle.sol";
import {ITenderPriceOracle} from "../../src/external/oracle/ITenderPriceOracle.sol";
import {GlpPriceOracle} from "../../src/oracle/GlpPriceOracle.sol";
import {IERC20Metadata as IERC20} from "oz/interfaces/IERC20Metadata.sol";
import {GMDPriceFeedFactory} from "../../src/oracle/GMDPriceOracle.sol";

library DeployOracle {
  function deploy() public returns (ITenderPriceOracle oracle) {
    oracle = new TenderPriceOracle();

    GlpPriceOracle glpOracle = new GlpPriceOracle();
    oracle.setOracle(IERC20(Addresses.fsGLP), glpOracle);

    GMDPriceFeedFactory factory = new GMDPriceFeedFactory();

    address[4] memory gmdCTokens = [
      0xB5dBDb01B08bff12E822EB28259ECCEb6cC91529,
      0xB60EF53BA18Bd85Ab642c2F78dF13e7aBCCdCb9c,
      0xe4843e44342617024F6b9d615dFfBe8858F8Ea16,
      0x80aEFB7dAde25542cc2f558Ee605aC2FC974Ceb9
    ];

    for (uint256 i = 0; i < gmdCTokens.length; i++) {
      IERC20 underlying = ICToken(gmdCTokens[i]).underlying();
      oracle.setOracle(underlying, factory.getGMDPriceFeed(address(underlying)));
    }
  }
}
