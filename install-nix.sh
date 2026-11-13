#!/usr/bin/env bash
set -euo pipefail

if nix_path="$(type -p nix)"; then
  echo "Aborting: Nix is already installed at ${nix_path}"
  exit
fi

if [[ ($OSTYPE =~ linux) && ($INPUT_ENABLE_KVM == 'true') ]]; then
  enable_kvm() {
    echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-install-nix-action-kvm.rules
    sudo udevadm control --reload-rules && sudo udevadm trigger --name-match=kvm
  }

  echo '::group::Enabling KVM support'
  enable_kvm && echo 'Enabled KVM' || echo 'KVM is not available'
  echo '::endgroup::'
fi

# GitHub command to put the following log messages into a group which is collapsed by default
echo "::group::Installing Nix"

# Create a temporary workdir
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# Configure Nix
add_config() {
  echo "$1" >>"$workdir/nix.conf"
}

# Enable traces by default to help with debugging
add_config "show-trace = true"
# Set jobs to number of cores
add_config "max-jobs = auto"
# Enable flakes and the new CLI
add_config "experimental-features = nix-command flakes"
# Always allow substituting from the cache, even if a derivation has `allowSubstitutes = false`.
# This is a CI optimisation to avoid having to download the inputs for already-cached derivations just to rebuild trivial text files.
add_config "always-allow-substitutes = true"
# Configure the nix-daemon to use certificates.
# In multi-user installs, NIX_SSL_CERT_FILE only works if set in the daemon's service file.
if [[ $OSTYPE =~ darwin ]]; then
  add_config "ssl-cert-file = /etc/ssl/cert.pem"
fi
# Allow binary caches specified at user level
if [[ $INPUT_SET_AS_TRUSTED_USER == 'true' ]]; then
  add_config "trusted-users = root ${USER:-}"
fi
# Add a GitHub access token.
# Token-less access is subject to lower rate limits.
if [[ -n "${INPUT_GITHUB_ACCESS_TOKEN:-}" ]]; then
  echo "::debug::Using the provided github_access_token for github.com"
  add_config "access-tokens = github.com=$INPUT_GITHUB_ACCESS_TOKEN"
# Use the default GitHub token if available.
# Skip this step if running an Enterprise instance. The default token there does not work for github.com.
elif [[ -n "${GITHUB_TOKEN:-}" && $GITHUB_SERVER_URL == "https://github.com" ]]; then
  echo "::debug::Using the default GITHUB_TOKEN for github.com"
  add_config "access-tokens = github.com=$GITHUB_TOKEN"
else
  echo "::debug::Continuing without a GitHub access token"
fi
# Append extra nix configuration if provided
if [[ -n "${INPUT_EXTRA_NIX_CONFIG:-}" ]]; then
  add_config "$INPUT_EXTRA_NIX_CONFIG"
fi

# Nix installer flags
installer_options=(
  --no-channel-add
  --nix-extra-conf-file "$workdir/nix.conf"
)

# Enable daemon on macOS and Linux systems with systemd, unless --no-daemon is specified
if [[ (! $INPUT_INSTALL_OPTIONS =~ "--no-daemon") && ($OSTYPE =~ darwin || -e /run/systemd/system) ]]; then
  use_daemon() { true; }
else
  use_daemon() { false; }
fi

if use_daemon; then
  installer_options+=(
    --daemon
    --daemon-user-count "$(python3 -c 'import multiprocessing as mp; print(mp.cpu_count() * 2)')"
  )
else
  # "fix" the following error when running nix*
  # error: the group 'nixbld' specified in 'build-users-group' does not exist
  add_config "build-users-group ="
  sudo mkdir -p /etc/nix
  sudo chmod 0755 /etc/nix
  sudo cp "$workdir/nix.conf" /etc/nix/nix.conf
fi

if [[ -n "${INPUT_INSTALL_OPTIONS:-}" ]]; then
  IFS=' ' read -r -a extra_installer_options <<<"$INPUT_INSTALL_OPTIONS"
  installer_options=("${extra_installer_options[@]}" "${installer_options[@]}")
fi

echo "installer options: ${installer_options[*]}"

# There is --retry-on-errors, but only newer curl versions support that
curl_retries=5
nix_version=2.35.6
# sha256 of https://releases.nixos.org/nix/nix-${nix_version}/install
# Kept in sync with nix_version by .github/workflows/update-nix.yml
nix_install_sha256=6f7bf206efb54cd4941fb274930dbc74fdfc16fcb06757ef261c8d7d69cfd60e

# Pick the installer and the hash to check it against:
#   - default installer: the pinned hash above, unless install_hash overrides it
#   - custom install_url: install_hash is required
if [[ -n "${INPUT_INSTALL_URL:-}" ]]; then
  install_url=$INPUT_INSTALL_URL
  expected_sha256=${INPUT_INSTALL_HASH:-}
  if [[ -z "$expected_sha256" ]]; then
    echo "::error::install_url is set but install_hash is not. Set install_hash to the SHA-256 of '$install_url'." >&2
    exit 1
  fi
else
  install_url="https://releases.nixos.org/nix/nix-${nix_version}/install"
  expected_sha256=${INPUT_INSTALL_HASH:-$nix_install_sha256}
fi

while ! curl -sS -o "$workdir/install" -v --fail -L "$install_url"; do
  sleep 1
  ((curl_retries--))
  if [[ $curl_retries -le 0 ]]; then
    echo "curl retries failed" >&2
    exit 1
  fi
done

# Verify the integrity of the installer
if command -v sha256sum >/dev/null 2>&1; then
  actual_sha256="$(sha256sum -b "$workdir/install" | cut -c1-64)"
elif command -v shasum >/dev/null 2>&1; then
  actual_sha256="$(shasum -a 256 -b "$workdir/install" | cut -c1-64)"
elif command -v openssl >/dev/null 2>&1; then
  actual_sha256="$(openssl dgst -r -sha256 "$workdir/install" | cut -c1-64)"
else
  echo "Cannot verify the SHA-256 hash of '$install_url'; you need one of 'sha256sum', 'shasum', or 'openssl'" >&2
  exit 1
fi

# Compare case-insensitively, hashes are often published in either case
# (tr instead of ${var,,}: macOS ships bash 3.2)
expected_sha256=$(tr '[:upper:]' '[:lower:]' <<<"$expected_sha256")
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
  echo "SHA-256 hash mismatch for '$install_url': expected $expected_sha256, got $actual_sha256" >&2
  exit 1
fi
echo "Verified SHA-256 of '$install_url': $actual_sha256"

sh "$workdir/install" "${installer_options[@]}"

# Configure the environment
#
# Adapted from the single- and multi-user scripts:
#   single-user: https://github.com/NixOS/nix/blob/master/scripts/nix-profile-daemon.sh.in
#   multi-user: https://github.com/NixOS/nix/blob/master/scripts/nix-profile-daemon.sh.in
#
# These scripts would normally be evaluated as part of the user's shell profile.
# GitHub doesn't evaluate profiles or rc scripts by default, so we set up the environment manually.
echo "::debug::Nix installed, setting up environment"

# Export the path to Nix
if [[ -n "${INPUT_NIX_PATH:-}" ]]; then
  echo "NIX_PATH=${INPUT_NIX_PATH}" >>"$GITHUB_ENV"
fi

# Set temporary directory if not already set
# Fixes https://github.com/cachix/install-nix-action/issues/197
if [[ -z "${TMPDIR:-}" ]]; then
  echo "TMPDIR=${RUNNER_TEMP}" >>"$GITHUB_ENV"
fi

# Determine the profile path.
#
# Different versions of Nix support (from newest to oldest):
#   - NIX_STATE_HOME to fully control the location of home files
#   - XDG_STATE_HOME, defaulting to .local/state/nix/profile
#   - $HOME/.nix-profile
#
# These directories are created by calling `nix profile`, so they don't exist at this point.
# Without parsing the Nix version, our best bet is the legacy-ish ~/.nix-profile.
if [[ -n "${NIX_STATE_HOME:-}" ]]; then
  NIX_LINK="$NIX_STATE_HOME/profile"
else
  NIX_LINK="$HOME/.nix-profile"
fi

# Set Nix profiles
echo "NIX_PROFILES=/nix/var/nix/profiles/default $NIX_LINK" >>"$GITHUB_ENV"

# Set NIX_SSL_CERT_FILE if not already configured
if [[ -z "${NIX_SSL_CERT_FILE:-}" ]]; then
  # Check common SSL certificate file locations
  if [[ -e "/etc/ssl/certs/ca-certificates.crt" ]]; then # NixOS, Ubuntu, Debian, Gentoo, Arch
    echo "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt" >>"$GITHUB_ENV"
  elif [[ $OSTYPE =~ darwin && -e "/etc/ssl/cert.pem" ]]; then # macOS
    echo "NIX_SSL_CERT_FILE=/etc/ssl/cert.pem" >>"$GITHUB_ENV"
  elif [[ -e "/etc/ssl/ca-bundle.pem" ]]; then # openSUSE Tumbleweed
    echo "NIX_SSL_CERT_FILE=/etc/ssl/ca-bundle.pem" >>"$GITHUB_ENV"
  elif [[ -e "/etc/ssl/certs/ca-bundle.crt" ]]; then # Old NixOS
    echo "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt" >>"$GITHUB_ENV"
  elif [[ -e "/etc/pki/tls/certs/ca-bundle.crt" ]]; then # Fedora, CentOS
    echo "NIX_SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt" >>"$GITHUB_ENV"
  elif [[ -e "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt" ]]; then # fall back to cacert in default Nix profile
    echo "NIX_SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt" >>"$GITHUB_ENV"
  elif [[ -e "$NIX_LINK/etc/ssl/certs/ca-bundle.crt" ]]; then # fall back to cacert in user Nix profile
    echo "NIX_SSL_CERT_FILE=$NIX_LINK/etc/ssl/certs/ca-bundle.crt" >>"$GITHUB_ENV"
  fi
fi

# Set paths based on the installation type
if use_daemon; then
  # Multi-user daemon install - add both paths
  echo "/nix/var/nix/profiles/default/bin" >>"$GITHUB_PATH"
fi
# Always add the user profile path
echo "$NIX_LINK/bin" >>"$GITHUB_PATH"

# Close the log message group which was opened above
echo "::endgroup::"
