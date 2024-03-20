// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Script} from 'forge-std/Script.sol';
import {DeployOracle} from './deploy/DeployOracle.sol';

contract Deploy is Script {
  function run() public {
    DeployOracle.deploy();
  }
}
