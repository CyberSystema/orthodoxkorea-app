#!/bin/sh

# ci_post_clone.sh — Xcode Cloud post-clone script
# Installs Skip (required for building the Android target via transpilation)

set -e

echo "Installing Skip..."
brew install skiptools/skip/skip

echo "Verifying Skip installation..."
skip checkup

echo "Skip installed successfully."
