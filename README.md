# Sablier Staking [![Github Actions][gha-badge]][gha] [![Coverage][codecov-badge]][codecov] [![Foundry][foundry-badge]][foundry] [![Discord][discord-badge]][discord]

[gha]: https://github.com/sablier-labs/staking/actions
[gha-badge]: https://github.com/sablier-labs/staking/actions/workflows/ci.yml/badge.svg
[codecov]: https://codecov.io/gh/sablier-labs/staking
[codecov-badge]: https://codecov.io/gh/sablier-labs/staking/branch/main/graph/badge.svg
[discord]: https://discord.gg/bSwRCwWRsT
[discord-badge]: https://img.shields.io/discord/659709894315868191
[foundry]: https://getfoundry.sh
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

In-depth documentation is available at [docs.sablier.com](https://docs.sablier.com).

## Background

TODO

## Usage

This is just a glimpse of Sablier Staking. For more guides and examples, see the
[documentation](https://docs.sablier.com).

## Architecture

TODO

### Branching Tree Technique

You may notice that some test files are accompanied by `.tree` files. This is called the Branching Tree Technique, and
it is explained in depth [here](https://www.bulloak.dev/).

## Deployments

The list of all deployment addresses can be found [here](https://docs.sablier.com).

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
