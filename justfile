# See https://github.com/sablier-labs/devkit/blob/main/just/evm.just
# Run just --list to see all available commands
import "./node_modules/@sablier/devkit/just/evm.just"

default:
  @just --list

clean:
  rm -rf "artifacts artifacts-* broadcast cache cache_hardhat-zk coverage docs out out-* typechain-types lcov.info"
  forge clean

coverage:
  forge coverage

gas-report:
  forge test --gas-report
