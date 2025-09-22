#!/usr/bin/env bash

set -euo pipefail

echo "=== Testing Nix Environment Variables ==="
echo

# Test NIX_PROFILES
echo "NIX_PROFILES: ${NIX_PROFILES:-<not set>}"
if [[ -n "${NIX_PROFILES:-}" ]]; then
  echo "✓ NIX_PROFILES is set"
else
  echo "✗ NIX_PROFILES is not set"
  exit 1
fi

# Test NIX_SSL_CERT_FILE
echo "NIX_SSL_CERT_FILE: ${NIX_SSL_CERT_FILE:-<not set>}"
if [[ -n "${NIX_SSL_CERT_FILE:-}" ]]; then
  if [[ -f "$NIX_SSL_CERT_FILE" ]]; then
    echo "✓ NIX_SSL_CERT_FILE is set and file exists"
  else
    echo "✗ NIX_SSL_CERT_FILE is set but file does not exist: $NIX_SSL_CERT_FILE"
    exit 1
  fi
else
  echo "✗ NIX_SSL_CERT_FILE is not set"
  exit 1
fi

# Test PATH contains Nix paths
echo "PATH: $PATH"
if echo "$PATH" | grep -E -q "(\.nix-profile|nix/profile)"; then
  echo "✓ PATH contains Nix paths"
else
  echo "✗ PATH does not contain Nix paths"
  exit 1
fi

# Test NIX_PATH if set
if [[ -n "${NIX_PATH:-}" ]]; then
  echo "NIX_PATH: $NIX_PATH"
  echo "✓ NIX_PATH is set"
else
  echo "NIX_PATH: <not set>"
  exit 1
fi

# Test TMPDIR
echo "TMPDIR: ${TMPDIR:-<not set>}"
if [[ -n "${TMPDIR:-}" ]]; then
  echo "✓ TMPDIR is set"
else
  echo "⚠ TMPDIR is not set"
  exit 1
fi

echo
echo "=== Testing Nix Command ==="
if command -v nix >/dev/null 2>&1; then
  echo "✓ nix command is available"
  echo "Nix version: $(nix --version)"
else
  echo "✗ nix command is not available"
  exit 1
fi

echo
echo "=== Environment Setup Test Complete ==="
