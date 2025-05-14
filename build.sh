#!/usr/bin/env bash
set -e

PYTHON_VERSION=3.13.0
ARCH=aarch64
PKG_NAME=python3.13
DEB_DIR="${PKG_NAME}_${PYTHON_VERSION}"
PREFIX_USR=$(pwd)/python-android

# Install dependencies (for local use; skip if running in CI with pre-installed deps)
if ! command -v aarch64-linux-gnu-gcc &>/dev/null; then
    echo "Installing required packages..."
    sudo apt update
    sudo apt install -y \
      clang \
      crossbuild-essential-arm64 \
      dpkg-dev \
      build-essential \
      wget \
      libffi-dev \
      libbz2-dev \
      libssl-dev \
      libncurses-dev \
      libreadline-dev \
      zlib1g-dev \
      xz-utils
fi

# Clean up
rm -rf "$PREFIX_USR" "$DEB_DIR"
mkdir -p "$PREFIX_USR"

# Download Python source
if [ ! -f Python-${PYTHON_VERSION}.tar.xz ]; then
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz
fi

tar xf Python-${PYTHON_VERSION}.tar.xz
cd Python-${PYTHON_VERSION}

# Cross-compilation environment
export CC=aarch64-linux-gnu-clang
export CXX=aarch64-linux-gnu-clang++
export AR=aarch64-linux-gnu-ar
export RANLIB=aarch64-linux-gnu-ranlib
export STRIP=aarch64-linux-gnu-strip
export READELF=aarch64-linux-gnu-readelf

export CFLAGS="--target=aarch64-linux-gnu -fPIC -O2"
export LDFLAGS="--target=aarch64-linux-gnu"

# Configure Python
./configure \
  --host=aarch64-linux-gnu \
  --build=$(uname -m)-linux-gnu \
  --prefix="$PREFIX_USR" \
  --enable-shared \
  --disable-ipv6 \
  ac_cv_file__dev_ptmx=yes \
  ac_cv_file__dev_ptc=no \
  ac_cv_func_working_mktime=yes \
  ac_cv_have_long_long_format=yes \
  ac_cv_printf_long_long=yes \
  ac_cv_func_lstat_dereferences_slashed_symlink=yes \
  CC="$CC" \
  CXX="$CXX" \
  AR="$AR" \
  RANLIB="$RANLIB" \
  STRIP="$STRIP" \
  CFLAGS="$CFLAGS" \
  LDFLAGS="$LDFLAGS"

make -j$(nproc)
make install

# Strip binaries
find "$PREFIX_USR" -type f \( -name "*.so" -o -perm -111 \) -exec "$STRIP" --strip-unneeded {} + || true

cd ..

# Create DEB package structure
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/data/data/com.termux/files/usr"
cp -a "$PREFIX_USR"/* "$DEB_DIR/data/data/com.termux/files/usr/"

# Create control file
cat > "$DEB_DIR/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $PYTHON_VERSION
Architecture: $ARCH
Maintainer: Termux Cross-Builder
Description: Python $PYTHON_VERSION cross-compiled for Termux (aarch64)
EOF

chmod 0755 "$DEB_DIR/DEBIAN"
chmod 0644 "$DEB_DIR/DEBIAN/control"

# Build DEB
dpkg-deb --build "$DEB_DIR"

echo "✅ Done: DEB package created at ${DEB_DIR}.deb"
