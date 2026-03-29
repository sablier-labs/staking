# See https://github.com/sablier-labs/devkit/blob/main/just/evm.just

# Run just --list to see all available commands

import "./node_modules/@sablier/devkit/just/evm.just"

default:
  @just --list

# Check Markdown formatting with mdformat
@mdformat-check +paths=".":
    mdformat --exclude "node_modules/**" --check {{ paths }}

# Format Markdown files with mdformat
@mdformat-write +paths=".":
    mdformat --exclude "node_modules/**" {{ paths }}
