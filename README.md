# Sablier Staking [![Github Actions][gha-badge]][gha] [![Coverage][codecov-badge]][codecov] [![Foundry][foundry-badge]][foundry] [![Discord][discord-badge]][discord]

[gha]: https://github.com/sablier-labs/staking/actions
[gha-badge]: https://github.com/sablier-labs/staking/actions/workflows/ci.yml/badge.svg
[codecov]: https://codecov.io/gh/sablier-labs/staking
[codecov-badge]: https://codecov.io/gh/sablier-labs/staking/branch/main/graph/badge.svg?token=unBESErDsQ
[discord]: https://discord.gg/bSwRCwWRsT
[discord-badge]: https://img.shields.io/discord/659709894315868191
[foundry]: https://getfoundry.sh
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

In-depth documentation is available at [docs.sablier.com](https://docs.sablier.com).

## Overview

Traditional staking protocols only support ERC20 tokens, leaving token stream holders unable to earn rewards on their
vesting or payment streams. This creates a significant opportunity cost for these users who decided to align themselves
with the long term growth of the token.

Sablier Staking is the first EVM protocol to enable staking of both ERC20 tokens and token streams at the same time.
This allows users to earn rewards on their vesting tokens without having to withdraw tokens from the streams or waiting
for their streams to end.

### Key Features

- **Permissionless**: Anyone can create and participate in staking campaigns without restrictions.
- **Stream support**: Stake ERC20 tokens and Sablier Lockup streams in the same campaign.
- **Immutability**: Campaign parameters cannot be changed once the campaign has been started.
- **No hidden opportunity cost**: Rewards are earned on the basis of the total underlying tokens in the streams, and not
  just available liquidity.
- **Flexibility**: Stake and unstake multiple times without losing earned rewards.

This unlocks new yield opportunities for the billions of dollars stuck in the illiquid vesting streams.

## Architecture

Tha technical design of the staking protocol is documented in the [ARCHITECTURE](./ARCHITECTURE.md) guide.

## Deployments

The list of all deployment addresses can be found [here](https://docs.sablier.com/guides/staking/deployments).

## Security

The codebase has undergone rigorous audits by leading security experts from Cantina, as well as independent auditors.
For a comprehensive list of all audits conducted, please click [here](https://github.com/sablier-labs/audits).

For any security-related concerns, please refer to the [SECURITY](./SECURITY.md) policy. This repository is subject to a
bug bounty program per the terms outlined in the aforementioned policy.

## Contributing

Feel free to dive in! [Open](https://github.com/sablier-labs/staking/issues/new) an issue,
[start](https://github.com/sablier-labs/staking/discussions/new) a discussion or submit a PR. For any informal concerns
or feedback, please join our [Discord server](https://discord.gg/bSwRCwWRsT).

For guidance on how to create PRs, see the [CONTRIBUTING](./CONTRIBUTING.md) guide.

## License

The primary license for Sablier Staking is the Business Source License 1.1 (`BUSL-1.1`), see
[`LICENSE.md`](./LICENSE.md). However, there are exceptions:

- All files in `src/interfaces/` and `src/types` are licensed under `GPL-3.0-or-later`, see
  [`LICENSE-GPL.md`](./LICENSE-GPL.md).
- Several files in `src`, `scripts/solidity`, and `tests` are licensed under `GPL-3.0-or-later`, see
  [`LICENSE-GPL.md`](./LICENSE-GPL.md).
- Many files in `tests/` remain unlicensed (as indicated in their SPDX headers).
