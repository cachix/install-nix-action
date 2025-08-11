# install-nix-action

![GitHub Actions badge](https://github.com/cachix/install-nix-action/workflows/install-nix-action%20test/badge.svg)

Installs [Nix](https://nixos.org/nix/) on GitHub Actions for the supported platforms: Linux and macOS.

By default it has no nixpkgs configured, you have to set `nix_path`
by [picking a channel](https://status.nixos.org/)
or [pin nixpkgs yourself](https://nix.dev/reference/pinning-nixpkgs)
(see also [pinning tutorial](https://nix.dev/tutorials/towards-reproducibility-pinning-nixpkgs)).

# Features

- Quick installation (~4s on Linux, ~20s on macOS)
- Multi-User installation (with sandboxing enabled only on Linux)
- [Self-hosted GitHub runner](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners) support
- Allows specifying Nix installation URL via `install_url` (the oldest supported Nix version is 2.3.5)
- Allows specifying extra Nix configuration options via `extra_nix_config`
- Allows specifying `$NIX_PATH` and channels via `nix_path`
- Share `/nix/store` between builds using [cachix-action](https://github.com/cachix/cachix-action) for simple binary cache setup to speed up your builds and share binaries with your team
- Enables KVM on supported machines: run VMs and NixOS tests with full hardware-acceleration

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
    - uses: actions/checkout@v4
    - uses: cachix/install-nix-action@v31
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
    - uses: actions/checkout@v4
    - uses: cachix/install-nix-action@v31
      with:
        github_access_token: ${{ secrets.GITHUB_TOKEN }}
    - run: nix build
    - run: nix flake check
```

To install Nix from any commit, go to [the corresponding installer_test action](https://github.com/NixOS/nix/runs/2219534360) and click on "Run cachix/install-nix-action@XX" step and expand the first line.

## Inputs (specify using `with:`)

- `extra_nix_config`: append to `/etc/nix/nix.conf`

- `github_access_token`: configure Nix to pull from GitHub using the given GitHub token. This helps work around rate limit issues. Has no effect when `access-tokens` is also specified in `extra_nix_config`.

- `install_url`: specify URL to install Nix from (useful for testing non-stable releases or pinning Nix, for example https://releases.nixos.org/nix/nix-2.3.7/install)

- `install_options`: additional installer flags passed to the installer script.

- `nix_path`: set `NIX_PATH` environment variable, for example `nixpkgs=channel:nixos-unstable`

- `enable_kvm`: whether to enable KVM for hardware-accelerated virtualization on Linux. Enabled by default if available.

- `set_as_trusted_user`: whether to add the current user to `trusted-users`. Enabled by default.


## Differences from the default Nix installer

Some settings have been optimised for use in CI environments:

- `nix.conf` settings. Override these defaults with `extra_nix_config`:

  - The experimental `flakes` and `nix-command` features are enabled. Disable by overriding `experimental-features` in `extra_nix_config`.

  - `max-jobs` is set to `auto`.

  - `show-trace` is set to `true`.

  - `$USER` is added to `trusted-users`.

  - `$GITHUB_TOKEN` is added to `access_tokens` if no other `github_access_token` is provided.

  - `always-allow-substitutes` is set to `true`.

  - `ssl-cert-file` is set to `/etc/ssl/cert.pem` on macOS.

- KVM is enabled on Linux if available. Disable by setting `enable_kvm: false`.

- `$TMPDIR` is set to `$RUNNER_TEMP` if empty.

---

## FAQ

### How do I print nixpkgs version I have configured?

```yaml
- name: Print nixpkgs version
  run: nix-instantiate --eval -E '(import <nixpkgs> {}).lib.version'
```

### How do I run NixOS tests?

With the following inputs:

```yaml
- uses: cachix/install-nix-action@vXX
  with:
    enable_kvm: true
    extra_nix_config: "system-features = nixos-test benchmark big-parallel kvm"
```

### How do I install packages via nix-env from the specified `nix_path`?

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
- uses: cachix/install-nix-action@v31
  with:
    extra_nix_config: |
      trusted-public-keys = hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
      substituters = https://hydra.iohk.io https://cache.nixos.org/
```

### How do I use `nix develop`?

`nix develop` can be used for `steps[*].shell`.

```yaml
  # optional step: build devShell in advance for accuracy of subsequent step timing and result
- name: Build devShell
  run: nix build --no-link .#devShell.$(uname -m)-linux

- name: Run a command with nix develop
  shell: 'nix develop -c bash -e {0}'
  run: echo "hello, pure world!"
```

### How do I pass environment variables to commands run with `nix develop` or `nix shell`?

Nix runs commands in a restricted environment by default, called `pure mode`.
In pure mode, environment variables are not passed through to improve the reproducibility of the shell.

You can use the `--keep / -k` flag to keep certain environment variables:

```yaml
- name: Run a command with nix develop
  run: nix develop --ignore-environment --keep MY_ENV_VAR --command echo $MY_ENV_VAR
  env:
    MY_ENV_VAR: "hello world"
```

Or you can disable pure mode entirely with the `--impure` flag:

```
nix develop --impure
```

### How do I pass AWS credentials to the Nix daemon?

In multi-user mode, Nix commands that operate on the Nix store are forwarded to a privileged daemon. This daemon runs in a separate context from your GitHub Actions workflow and cannot access the workflow's environment variables. Consequently, any secrets or credentials defined in your workflow environment will not be available to Nix operations that require store access.

There are two ways to pass AWS credentials to the Nix daemon:
  - Configure a default profile using the AWS CLI
  - Install Nix in single-user mode

#### Configure a default profile using the AWS CLI

The Nix daemon supports reading AWS credentials from the `~/.aws/credentials` file.

We can use the AWS CLI to configure a default profile using short-lived credentials fetched using OIDC:

```yaml
job:
  build:
    runs-on: ubuntu-latest
    # Required permissions to request AWS credentials
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v31
      - name: Assume AWS Role
        uses: aws-actions/configure-aws-credentials@v4.1.0
        with:
          aws-region: us-east-1
          role-to-assume: arn:aws-cn:iam::123456789100:role/my-github-actions-role
      - name: Make AWS Credentials accessible to nix-daemon
        run: |
          sudo -i aws configure set aws_access_key_id "${AWS_ACCESS_KEY_ID}"
          sudo -i aws configure set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}"
          sudo -i aws configure set aws_session_token "${AWS_SESSION_TOKEN}"
          sudo -i aws configure set region "${AWS_REGION}"
```

#### Install Nix in single-user mode

In some environments it may be possible to install Nix in single-user mode by passing the `--no-daemon` flag to the installer.
This mode is normally used on platforms without an init system, like systemd, and in containerized environments with a single user that can own the entire Nix store.

This approach is more generic as it allows passing environment variables directly to Nix, including secrets, proxy settings, and other configuration options.

However, it may not be suitable for all environments. [Consult the Nix manual](https://nix.dev/manual/nix/latest/installation/nix-security) for the latest restrictions and differences between the two modes.

For example, single-user mode is currently supported on hosted Linux GitHub runners, like `ubuntu-latest`.
It is not supported on macOS runners, like `macos-latest`.

```yaml
- uses: cachix/install-nix-action@v31
  with:
    install_options: --no-daemon
```
