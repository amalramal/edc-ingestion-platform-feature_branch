#!/usr/bin/env zsh
#
# This script installs the following packages via brew
#   - tfenv
#   - tflint
#   - terraform-docs
#   - pre-commit
#   - tfsec
#   - coreutils
#   - bash
#
# If the package is found on your system already, this script will attempt to
# update it via brew. If the package has not been installed via brew it will
# not do anything.

echo '[*] Updating brew'
brew update

echo '[*] Installing Packages'
for pkg in tfenv tflint terraform-docs pre-commit tfsec coreutils bash
do
  which $pkg > /dev/null
  PKG_INSTALLED=$? # Installed=0, Not installed=1

  if [[ $PKG_INSTALLED -eq 0 ]];
  then
    # Package is present on system, check to update via brew
    brew list $pkg > /dev/null 2>&1
    INSTALLED_VIA_BREW=$? # 0=installed with brew

    if [[ $INSTALLED_VIA_BREW -eq 0 ]];
    then
      echo "  Updating $pkg via brew..."
      brew upgrade $pkg
    else
      echo "  $pkg installed, but not with brew. Ignoring..."
    fi
  else
    # Package is not installed, install with brew
    echo "  Installing $pkg via brew..."
    brew install $pkg
  fi
done

echo '[*] Installing pre-commit hooks'
pre-commit install
pre-commit install --hook-type commit-msg

echo '[*] Setting pre-commit hooks to auto-install on clone in the future'
git config --global init.templateDir ~/.git-template
pre-commit init-templatedir ~/.git-template

echo '[*] Installing terraform with tfenv'
tfenv install

echo '[*] Initializing tflint plugins'
TFLINT_CONFIG_FILE=$(pwd)/$(dirname "$0")/../.tflint.hcl
tflint -c $TFLINT_CONFIG_FILE --init
