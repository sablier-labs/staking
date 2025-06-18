#!/usr/bin/env bash

# Pre-requisites:
# - foundry (https://getfoundry.sh)
# - ni (https://github.com/antfu-collective/ni)
# - just (https://github.com/casey/just)

# Strict mode: https://gist.github.com/vncsna/64825d5609c146e80de8b1fd623011ca
set -euo pipefail

# Delete the current artifacts
artifacts=./artifacts
rm -rf $artifacts

# Create the new artifacts directories
mkdir $artifacts \
  "$artifacts/interfaces" \
  "$artifacts/libraries"

# Generate the artifacts
just build-optimized

# Copy the production artifacts
cp out-optimized/SablierStaking.sol/SablierStaking.json $artifacts

interfaces=./artifacts/interfaces
cp out-optimized/ISablierLockupNFT.sol/ISablierLockupNFT.json $interfaces
cp out-optimized/ISablierStaking.sol/ISablierStaking.json $interfaces
cp out-optimized/ISablierStakingState.sol/ISablierStakingState.json $interfaces

libraries=./artifacts/libraries
cp out-optimized/Errors.sol/Errors.json $libraries

# Format the artifacts with Prettier
bun prettier --write ./artifacts