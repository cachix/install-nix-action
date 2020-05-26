#!/usr/bin/env bash
set -euo pipefail

export here=$(dirname "${BASH_SOURCE[0]}")

nixConf() {
  sudo mkdir -p /etc/nix
  # Workaround a segfault: https://github.com/NixOS/nix/issues/2733
  sudo sh -c 'echo http2 = false >> /etc/nix/nix.conf'
  # Set jobs to number of cores
  sudo sh -c 'echo max-jobs = auto >> /etc/nix/nix.conf'
  # Allow binary caches for runner user
  sudo sh -c 'echo trusted-users = root runner >> /etc/nix/nix.conf'
}

if [[ $OSTYPE =~ darwin ]]; then
  # Catalina workaround https://github.com/NixOS/nix/issues/2925
  $here/create-darwin-volume.sh

  # Disable spotlight indexing of /nix to speed up performance
  sudo mdutil -i off /nix
fi

nixConf

# Needed due to multi-user being too defensive
export ALLOW_PREEXISTING_INSTALLATION=1

sh <(curl -L ${INPUT_INSTALL_URL:-https://nixos.org/nix/install}) --daemon

# write nix.conf again as installation overwrites it
nixConf

# macOS needs certificates hints
if [[ $OSTYPE =~ darwin ]]; then
  cert_file=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt
  echo "::set-env name=NIX_SSL_CERT_FILE::$cert_file"
  export NIX_SSL_CERT_FILE=$cert_file
  sudo launchctl setenv NIX_SSL_CERT_FILE "$cert_file"
fi

# Reload the daemon to pick up changes
sudo pkill -HUP nix-daemon

# Set paths
echo "::add-path::/nix/var/nix/profiles/per-user/runner/profile/bin"
echo "::add-path::/nix/var/nix/profiles/default/bin"
echo "::set-env name=NIX_PATH::/nix/var/nix/profiles/per-user/root/channels"