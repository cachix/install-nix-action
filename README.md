# install-nix-action

check 
![github actions badge](https://github.com/cachix/install-nix-action/workflows/install-nix-action%20test/badge.svg)

Installs [Nix](https://nixos.org/nix/) on GitHub Actions for the supported platforms: Linux and macOS.

By default it has no nixpkgs configured, you have to set `nix_path`
by [picking a channel](https://status.nixos.org/)
or [pin nixpkgs yourself](https://nix.dev/reference/pinning-nixpkgs.html) 
(see also [pinning tutorial](https://nix.dev/tutorials/towards-reproducibility-pinning-nixpkgs.html)).

# Features

- Quick installation (~4s on Linux, ~20s on macOS)
- Multi-User installation (with sandboxing enabled only on Linux)
- [Self-hosted github runner](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners) support
- Allows specifying Nix installation URL via `install_url` (the oldest supported Nix version is 2.3.5)
- Allows specifying extra Nix configration options via `extra_nix_config`
- Allows specifying `$NIX_PATH` and channels via `nix_path`
- Share `/nix/store` between builds using [cachix-action](https://github.com/cachix/cachix-action) for simple binary cache setup to speed up your builds and share binaries with your team
- Enables `flakes` and `nix-command` experimental features by default (to disable, set ``experimental-features`` via ``extra_nix_config``) 

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
    - uses: actions/checkout@v3
    - uses: cachix/install-nix-action@v18
      with:
        nix_path: nixpkgs=channel:nixos-unstable
    - run: nix-build
```


## Usage with Flakes

```yaml
name: "Test"
on:
  pull_request:
  push:
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: cachix/install-nix-action@v18
      with:
        extra_nix_config: |
          access-tokens = github.com=${{ secrets.GITHUB_TOKEN }}
    - run: nix build
    - run: nix flake check
```

To install Nix from any commit, go to [the corresponding installer_test action](https://github.com/NixOS/nix/runs/2219534360) and click on "Run cachix/install-nix-action@XX" step and expand the first line.

## Inputs (specify using `with:`)

- `install_url`: specify URL to install Nix from (useful for testing non-stable releases or pinning Nix for example https://releases.nixos.org/nix/nix-2.3.7/install)

- `nix_path`: set `NIX_PATH` environment variable, for example `nixpkgs=channel:nixos-unstable`

- `extra_nix_config`: append to `/etc/nix/nix.conf`

---

## FAQ

### How do I print nixpkgs version I have configured?


```yaml
- name: Print nixpkgs version
  run: nix-instantiate --eval -E '(import <nixpkgs> {}).lib.version'
```

### How can I run NixOS tests?

With the following inputs:

```yaml
- uses: cachix/install-nix-action@vXX
  with:
    extra_nix_config: "system-features = nixos-test benchmark big-parallel kvm"
```

[Note that there's no hardware acceleration on GitHub Actions.](https://github.com/actions/virtual-environments/issues/183#issuecomment-610723516).

### How can I install packages via nix-env from the specified `nix_path`?

```
nix-env -i mypackage -f '<nixpkgs>'
```

### How do I add a binary cache?

If the binary cache you want to add is hosted on [Cachix](https://cachix.org/) and you are
using [cachix-action](https://github.com/cachix/cachix-action), you
should use their `extraPullNames` input like this:

```yaml
- uses: cachix/cachix-action@vXX
   with:
     name: mycache
     authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'
     extraPullNames: nix-community
```

Otherwise, you can add any binary cache to nix.conf using
install-nix-action's own `extra_nix_config` input:

```yaml
- uses: cachix/install-nix-action@v18
  with:
    extra_nix_config: |
      trusted-public-keys = hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
      substituters = https://hydra.iohk.io https://cache.nixos.org/
```

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
