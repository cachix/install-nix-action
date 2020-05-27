# install-nix-action

![github actions badge](https://github.com/cachix/install-nix-action/workflows/install-nix-action%20test/badge.svg)

Installs [Nix](https://nixos.org/nix/) on GitHub Actions for the supported platforms: Linux and macOS.

## Usage

Create `.github/workflows/test.yml` in your repo with the following contents:

```yaml
name: "Test"
on:
  pull_request:
  push:
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: cachix/install-nix-action@v9
    - run: nix-build
```

See also [cachix-action](https://github.com/cachix/cachix-action) for
simple binary cache setup to speed up your builds and share binaries
with developers.

## Options `with: ...`

- `install_url`: specify URL to install Nix from (mostly useful for testing non-stable releases

- `skip_adding_nixpkgs_channel`: set to `true` to skip adding nixpkgs-unstable channel (and save ~5s for each job build)

---

## Hacking

Install the dependencies
```bash
$ yarn install
```

Build the typescript
```bash
$ yarn build
```

Run the tests :heavy_check_mark:
```bash
$ yarn test
```
