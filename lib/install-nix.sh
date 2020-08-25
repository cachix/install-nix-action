#!/usr/bin/env bash
set -euo pipefail

# Set jobs to number of cores
sudo sh -c 'echo max-jobs = auto >> /tmp/nix.conf'
# Allow binary caches for runner user
sudo sh -c 'echo trusted-users = root runner >> /tmp/nix.conf'
# Append extra nix configuration if provided
if [[ -n $INPUT_EXTRA_NIX_CONFIG ]]; then
  echo "$INPUT_EXTRA_NIX_CONFIG" | sudo tee -a /tmp/nix.conf >/dev/null
fi

install_options=(
  --daemon
  --daemon-user-count 4
  --nix-extra-conf-file /tmp/nix.conf
  --darwin-use-unencrypted-nix-store-volume
)

if [[ $INPUT_SKIP_ADDING_NIXPKGS_CHANNEL = "true" || -n $INPUT_NIX_PATH ]]; then
  install_options+=(--no-channel-add)
else
  INPUT_NIX_PATH="/nix/var/nix/profiles/per-user/root/channels"
fi

sh <(curl --retry 5 --retry-connrefused -L "${INPUT_INSTALL_URL:-https://nixos.org/nix/install}") \
  "${install_options[@]}"

if [[ $OSTYPE =~ darwin ]]; then
  # Disable spotlight indexing of /nix to speed up performance
  sudo mdutil -i off /nix

  # macOS needs certificates hints
  cert_file=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt
  echo "::set-env name=NIX_SSL_CERT_FILE::$cert_file"
  export NIX_SSL_CERT_FILE=$cert_file
  sudo launchctl setenv NIX_SSL_CERT_FILE "$cert_file"
fi

# Set paths
echo "::add-path::/nix/var/nix/profiles/per-user/runner/profile/bin"
echo "::add-path::/nix/var/nix/profiles/default/bin"

if [[ $INPUT_NIX_PATH != "" ]]; then
  echo "::set-env name=NIX_PATH::${INPUT_NIX_PATH}"
fi
