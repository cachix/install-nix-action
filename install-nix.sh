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
add_config "show-trace = true"
# Set jobs to number of cores
add_config "max-jobs = auto"
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
if [[ ! $INPUT_EXTRA_NIX_CONFIG =~ "experimental-features" ]]; then
  add_config "experimental-features = nix-command flakes"
fi
# Always allow substituting from the cache, even if the derivation has `allowSubstitutes = false`.
# This is a CI optimisation to avoid having to download the inputs for already-cached derivations to rebuild trivial text files.
if [[ ! $INPUT_EXTRA_NIX_CONFIG =~ "always-allow-substitutes" ]]; then
  add_config "always-allow-substitutes = true"
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
nix_version=2.33.3
while ! curl -sS -o "$workdir/install" -v --fail -L "${INPUT_INSTALL_URL:-https://releases.nixos.org/nix/nix-${nix_version}/install}"; do
  sleep 1
  ((curl_retries--))
  if [[ $curl_retries -le 0 ]]; then
    echo "curl retries failed" >&2
    exit 1
  fi
done

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
