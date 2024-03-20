.PHONY: test-upgrade

test-upgrade: ./test/UpgradeOracle.t.sol
	forge t -f http://localhost:8545 --mp ./test/UpgradeOracle.t.sol

test-upgrade-v: ./test/UpgradeOracle.t.sol
	forge t -f http://localhost:8545 --mp ./test/UpgradeOracle.t.sol -vv

anvil:
	anvil --chain-id 42161 -f https://arb1.arbitrum.io/rpc
