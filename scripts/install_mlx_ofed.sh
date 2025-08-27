#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

MLX_OFED_VERSION="24.10-1.1.4.0"
OS_VERSION="ubuntu22.04-x86_64"

SUDO=''
[[ $EUID -ne 0 ]] && SUDO=sudo

install_mlx() {
	if [ -d /tmp/mlx ]; then
		$SUDO rm -rf /tmp/mlx
	fi
	mkdir /tmp/mlx
	pushd /tmp/mlx
	curl -L https://content.mellanox.com/ofed/MLNX_OFED-${MLX_OFED_VERSION}/MLNX_OFED_LINUX-${MLX_OFED_VERSION}-${OS_VERSION}.tgz | \
    		tar xz -C . --strip-components=2
	$SUDO ./mlnxofedinstall --without-fw-update --force
	popd
}

cleanup_image() {
	$SUDO rm -rf /tmp/mlx
}

check_installed() {
  if ! $(which ofed_info) > /dev/null; then
    installed=false
  else
    installed=true
  fi
}

(return 2>/dev/null) && echo "Sourced" && return

# check_installed
installed=false

if [[ $installed == true ]]; then
  echo "MLX OFED is already installed"
else
  echo "Installing MLX OFED driver..."
  install_mlx

  echo "Cleaning up..."
  cleanup_image
fi
