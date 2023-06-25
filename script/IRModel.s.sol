// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;
import {JumpRateModelGLP} from '../src/compound/JumpRateModelGLP.sol';
import {Script} from 'forge-std/Script.sol';
import {IComptroller} from "../src/external/compound/Comptroller.sol";
import {ICToken} from "../src/external/compound/ICToken.sol";
import {Addresses} from "./Addresses.sol";
import {console2 as console} from 'forge-std/console2.sol';

contract Deploy is Script {
  ICToken[] private markets = [
    ICToken(payable(Addresses.tWBTC)),
    ICToken(payable(Addresses.tLINK)),
    ICToken(payable(Addresses.tUNI)),
    ICToken(payable(Addresses.tUSDC)),
    ICToken(payable(Addresses.tUSDT)),
    ICToken(payable(Addresses.tDAI)),
    ICToken(payable(Addresses.tFRAX)),
    ICToken(payable(Addresses.tARB)),
    ICToken(payable(Addresses.tMAGIC)),
    ICToken(payable(Addresses.tWETH))
  ];
  function run() public {
    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));
    address irModel = address(new JumpRateModelGLP(Addresses.admin));
    for(uint i = 0; i < markets.length; i++) {
      ICToken market = markets[i];
      console.log(market.admin());
      market._setInterestRateModel(irModel);
    }
    vm.stopBroadcast();
  }
}
