#!/bin/bash
# Prerequisite set-up script for Drake on Ubuntu 16.04.
# 16.04 support is in beta. It is not tested in CI or officially supported.

set -eu

die () {
    echo "$@" 1>&2
    exit 1
}

me="The Drake prerequisite set-up script"

[[ $EUID -eq 0 ]] || die "$me must run as root. Please use sudo."

. /etc/lsb-release

[[ $DISTRIB_RELEASE == "16.04" ]] || die "$me only supports Ubuntu 16.04."

# Install Clang 3.9
while true; do
  echo "The Ubuntu 16.04 distribution includes Clang 3.8 by default."
  echo "To install Clang 3.9 it is necessary to add a Personal Package Archive (PPA)."
  echo "This script will add the repository
    'deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-3.9 main'"
  read -p "Do you want to continue? [Y/n] " yn
  case $yn in
    [Yy]*)
      apt-get install --no-install-recommends lsb-core software-properties-common wget
      wget -q -O - http://llvm.org/apt/llvm-snapshot.gpg.key | sudo apt-key add -
      add-apt-repository -y "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-3.9 main"
      apt-get update
      apt install --no-install-recommends clang-3.9 lldb-3.9
      break
      ;;
    [Nn]*) break ;;
    *) echo "Please answer yes or no." ;;
  esac
done

# The CI scripts require a newer version of CMake than apt installs.
# Only install CMake if it's not installed or older than 3.5.
install_cmake=true
if command -v cmake &>/dev/null; then
  cmake_version=$(cmake --version) &>/dev/null
  cmake_version=${cmake_version:14:3}
  if dpkg --compare-versions $cmake_version ge 3.5; then
    echo "CMake is already installed ($cmake_version)"
    install_cmake=false
  fi
fi
if $install_cmake; then
  apt install --no-install-recommends cmake
  apt install --no-install-recommends cmake-curses-gui
fi

# Install the APT dependencies.
apt update -y
# TODO(david-german-tri): Can we remove libvtk-java?
apt install --no-install-recommends $(tr '\n' ' ' <<EOF

alien
autoconf
automake
bash-completion
bison
clang-format
default-jdk
doxygen
fakeroot
flex
freeglut3-dev
g++
g++-5
g++-5-multilib
gdb
gfortran
gfortran-5
gfortran-5-multilib
git
graphviz
libboost-dev
libboost-system-dev
libgtk2.0-dev
libhtml-form-perl
libmpfr-dev
libpng12-dev
libqt4-dev
libqt4-opengl-dev
libqwt-dev
libtinyxml-dev
libtool
libvtk-java
libvtk5-dev
libvtk5-qt4-dev
libxmu-dev
make
ninja-build
perl
pkg-config
python-bs4
python-dev
python-gtk2
python-html5lib
python-lxml
python-numpy
python-pygame
python-scipy
python-sphinx
python-vtk
python-yaml
unzip
valgrind
zip
zlib1g-dev

EOF
    )

# Install Bazel.
wget -O /tmp/bazel_0.4.5-linux-x86_64.deb https://github.com/bazelbuild/bazel/releases/download/0.4.5/bazel_0.4.5-linux-x86_64.deb
if echo "b494d0a413e4703b6cd5312403bea4d92246d6425b3be68c9bfbeb8cc4db8a55 /tmp/bazel_0.4.5-linux-x86_64.deb" | sha256sum -c -; then
  dpkg -i /tmp/bazel_0.4.5-linux-x86_64.deb
else
  echo "The Bazel deb does not have the expected SHA256.  Not installing Bazel."
  exit 1
fi

rm /tmp/bazel_0.4.5-linux-x86_64.deb

# Repair a bad Bazel/ccache interaction.
# See https://github.com/RobotLocomotion/drake/issues/4464.
# See https://github.com/bazelbuild/bazel/issues/1322.
$(dirname $0)/ccache-bazel-wrapper-mkdeb.sh --install

# TODO(david-german-tri): Do we need to munge the MATLAB C++ libraries?
# http://drake.mit.edu/ubuntu.html#matlab

