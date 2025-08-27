#!/bin/bash

set -xeuo pipefail

# script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# DPDK version
DPDK_VERSION="20.11"

function usage() {
  echo "Usage: $0 {setup | install_dpdk | install_ofed | all}"
  exit 1
}

# If $1 is not set, print usage
if [ -z "${1:-}" ]; then
  usage
  exit 1
fi

# Install general tools
function system_setup() {
  vendor=$(grep -m 1 "vendor_id" /proc/cpuinfo)

  sudo apt update
  sudo apt install -y linux-tools-common linux-tools-`uname -r` htop
  sudo apt install -y meson ninja-build pkg-config python3-pip libnuma-dev
  pip install pyelftools

  # Install plot packages
  sudo apt install -y python3-pip
  pip install matplotlib pandas

  if [[ "$vendor" == *"GenuineIntel"* ]]; then
    # Set scaling governor to performance
    sudo cpupower frequency-set --governor performance

    # Disable turbo
    echo "1" | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
  fi

  # Turn off SMT
  if [ $(cat /sys/devices/system/cpu/smt/control) = "on" ]; then
    echo "Disabling SMT (Simultaneous Multithreading)..."
    echo off | sudo tee /sys/devices/system/cpu/smt/control
  fi
}

function install_ofed() {
# Install mellanox OFED
  bash ${SCRIPT_DIR}/install_mlx_ofed.sh
}

function install_dpdk() {
  # Install DPDK
  rm -rf dpdk
  sudo rm -rf /usr/local/lib/x86_64-linux-gnu/
  git clone https://dpdk.org/git/dpdk
  cd dpdk
  git checkout v${DPDK_VERSION}
  meson -Ddisable_drivers=common/octeontx,common/octeontx2 build
  ninja -C build
  sudo ninja -C build install
  sudo ldconfig
}

# Command line arguments
if [ "$1" == "install_dpdk" ]; then
	install_dpdk
elif [ "$1" == "install_ofed" ]; then
	install_ofed
elif [ "$1" == "setup" ]; then
  system_setup
elif [ "$1" == "all" ]; then
  system_setup
  install_ofed
  install_dpdk
else
  usage
  exit 1
fi
