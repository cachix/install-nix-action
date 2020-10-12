#!/usr/bin/env bash
set -euo pipefail

# Configure Nix
add_config() {
  echo "$1" | sudo tee -a /tmp/nix.conf >/dev/null
}
# Set jobs to number of cores
add_config "max-jobs = auto"
# Allow binary caches for user
add_config "trusted-users = root $USER"
# Append extra nix configuration if provided
if [[ $INPUT_EXTRA_NIX_CONFIG != "" ]]; then
  add_config "$INPUT_EXTRA_NIX_CONFIG"
fi

# Nix installer flags
installer_options=(
  --daemon
  --daemon-user-count 4
  --no-channel-add
  --darwin-use-unencrypted-nix-store-volume
  --nix-extra-conf-file /tmp/nix.conf
)

# On self-hosted runners we don't need to install more than once
if [[ ! -d /nix/store ]] 
then 
  sh <(curl --retry 5 --retry-connrefused -L "${INPUT_INSTALL_URL:-https://nixos.org/nix/install}") "${installer_options[@]}"
fi

if [[ $OSTYPE =~ darwin ]]; then
  # Disable spotlight indexing of /nix to speed up performance
  sudo mdutil -i off /nix

  # macOS needs certificates hints
  cert_file=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt
  echo "NIX_SSL_CERT_FILE=$cert_file" >> $GITHUB_ENV
  export NIX_SSL_CERT_FILE=$cert_file
  sudo launchctl setenv NIX_SSL_CERT_FILE "$cert_file"
fi

# Set paths
echo "/nix/var/nix/profiles/per-user/$USER/profile/bin" >> $GITHUB_PATH
echo "/nix/var/nix/profiles/default/bin" >> $GITHUB_PATH

if [[ $INPUT_NIX_PATH != "" ]]; then
  echo "NIX_PATH=${INPUT_NIX_PATH}" >> $GITHUB_ENV
fi
