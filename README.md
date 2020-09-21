# install-nix-action

![github actions badge](https://github.com/cachix/install-nix-action/workflows/install-nix-action%20test/badge.svg)

Installs [Nix](https://nixos.org/nix/) on GitHub Actions for the supported platforms: Linux and macOS.

By default it has no nixpkgs configured, you have to set `nix_path`
by [picking a channel](https://status.nixos.org/)
or [pin nixpkgs yourself](https://nix.dev/tutorials/towards-reproducibility-pinning-nixpkgs.html).

# Features

- Quick installation (~4s on Linux, ~20s on macOS)
- Multi-User installation (with sandboxing enabled only on Linux)
- [Self-hosted github runner](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners) support
- Allows specifying Nix installation URL via `install_url`
- Allows specifying extra Nix configration options via `extra_nix_config`
- Allows specifying `$NIX_PATH` and channels via `nix_path`

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
    - uses: cachix/install-nix-action@v11
      with:
        nix_path: nixpkgs=channel:nixos-unstable
    - run: nix-build
```

See also [cachix-action](https://github.com/cachix/cachix-action) for
simple binary cache setup to speed up your builds and share binaries
with developers.

## Usage with Flakes

```
name: "Test"
on:
  pull_request:
  push:
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
      with:
          # Nix Flakes doesn't work on shallow clones
          fetch-depth: 0
    - uses: cachix/install-nix-action@v11
      with:
        install_url: https://github.com/numtide/nix-flakes-installer/releases/download/nix-3.0pre20200820_4d77513/install
        extra_nix_config: |
          experimental-features = nix-command flakes
    - run: nix-build
```

## Inputs (specify using `with:`)

- `install_url`: specify URL to install Nix from (useful for testing non-stable releases)

- `nix_path`: set `NIX_PATH` environment variable, for example `nixpkgs=channel:nixos-unstable`

- `extra_nix_config`: append to `/etc/nix/nix.conf`

---

## FAQ

### Is it possible to run NixOS tests / Qemu+KVM with GitHub Actions?

[Currently GitHub Actions are not running on Azure instance types that support nested virtualization](https://github.com/actions/virtual-environments/issues/183#issuecomment-610723516).

### How do I print nixpkgs version with the channel I have configured?


```nix-instantiate --eval -E '(import <nixpkgs> {}).lib.version'```

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
