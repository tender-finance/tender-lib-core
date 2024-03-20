// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Script} from 'forge-std/Script.sol';
import {DeployGlpWETHOracle} from './deploy/DeployGlpWETHOracle.sol';

contract UpgradeGlp is Script {
  function run() public {
    DeployGlpWETHOracle.deploy();
  }
}
