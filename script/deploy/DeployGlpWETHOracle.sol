// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IChainlinkPriceOracle} from "../../src/external/oracle/IChainlinkPriceOracle.sol";
import {GlpPriceOraclev2} from "../../src/oracle/GlpPriceOraclev2.sol";
import {Addresses} from "../shared/Addresses.sol";
import {TenderPriceOracle} from "../../src/oracle/TenderPriceOracle.sol";
import {ITenderPriceOracle} from "../../src/external/oracle/ITenderPriceOracle.sol";
import {IERC20Metadata as IERC20} from "oz/interfaces/IERC20Metadata.sol";
import {ICToken} from "../../src/external/compound/ICToken.sol";

library DeployGlpWETHOracle {
	function deploy() public returns (GlpPriceOraclev2 glpOracle) {
		glpOracle = new GlpPriceOraclev2(ICToken(Addresses.tWETH));
	}
}
