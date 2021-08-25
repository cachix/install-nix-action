#!/usr/bin/env bash
set -euo pipefail

if type -p nix &>/dev/null ; then
  echo "Aborting: Nix is already installed at $(type -p nix)"
  exit
fi

# Configure Nix
add_config() {
  echo "$1" | tee -a /tmp/nix.conf >/dev/null
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
  --no-channel-add
  --darwin-use-unencrypted-nix-store-volume
  --nix-extra-conf-file /tmp/nix.conf
)

# only use the nix-daemon settings if on darwin (which get ignored) or systemd is supported
if [[ $OSTYPE =~ darwin || -e /run/systemd/system ]]; then
  installer_options+=(
    --daemon
    --daemon-user-count 4
  )
else
  # "fix" the following error when running nix*
  # error: the group 'nixbld' specified in 'build-users-group' does not exist
  mkdir -m 0755 /etc/nix
  echo "build-users-group =" > /etc/nix/nix.conf
fi

if [[ $INPUT_INSTALL_OPTIONS != "" ]]; then
  IFS=' ' read -r -a extra_installer_options <<< $INPUT_INSTALL_OPTIONS
  installer_options=("${extra_installer_options[@]}" "${installer_options[@]}")
fi

echo "installer options: ${installer_options[@]}"
sh <(curl --retry 5 --retry-connrefused -L "${INPUT_INSTALL_URL:-https://nixos.org/nix/install}") "${installer_options[@]}"

if [[ $OSTYPE =~ darwin ]]; then
  # Disable spotlight indexing of /nix to speed up performance
  sudo mdutil -i off /nix

  # macOS needs certificates hints
  cert_file=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt
  echo "NIX_SSL_CERT_FILE=$cert_file" >> "$GITHUB_ENV"
  export NIX_SSL_CERT_FILE=$cert_file
  sudo launchctl setenv NIX_SSL_CERT_FILE "$cert_file"
fi

# Set paths
echo "/nix/var/nix/profiles/per-user/$USER/profile/bin" >> "$GITHUB_PATH"
echo "/nix/var/nix/profiles/default/bin" >> "$GITHUB_PATH"

if [[ $INPUT_NIX_PATH != "" ]]; then
  echo "NIX_PATH=${INPUT_NIX_PATH}" >> "$GITHUB_ENV"
fi
