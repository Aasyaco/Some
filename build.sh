#/data/data/com.termux/files/usr/bin/bash
set -e

# 🧹 Set environment
PYTHON_VERSION=3.13.0
PREFIX_USR=$PWD/python-3.13
OPENSSL_DIR=/usr

# 🧹 Clean previous
rm -rf $PREFIX_USR
mkdir -p $PREFIX_USR

# 📦 Download Python 3.13 if not present
if [ ! -f Python-${PYTHON_VERSION}.tar.xz ]; then
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz
fi

# 🗂️ Extract and enter source
rm -rf Python-${PYTHON_VERSION}
tar xf Python-${PYTHON_VERSION}.tar.xz
cd Python-${PYTHON_VERSION}

# ⚡ Max Optimization flags
export CFLAGS="-fPIC -DANDROID -O3 -march=native -mtune=native -fomit-frame-pointer -pipe -flto"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,-rpath=/data/data/com.termux/files/usr/lib -flto"
export MAKEFLAGS="-j$(nproc)"

# 🧠 Configure with maximum optimizations
./configure \
    --prefix=$PREFIX_USR \
    --enable-optimizations \
    --with-lto \
    --enable-shared \
    --disable-ipv6 \
    --with-openssl=$OPENSSL_DIR \
    --disable-test-modules \
    ac_cv_file__dev_ptmx=yes \
    ac_cv_file__dev_ptc=no \
    ac_cv_have_long_long_format=yes \
    ac_cv_printf_long_long=yes \
    ac_cv_func_lstat_dereferences_slashed_symlink=yes \
    ac_cv_func_working_mktime=yes

# 🛠️ Build Python
make

# 📦 Install into PREFIX folder
make install

# 🧹 Clean up
cd ..
echo "✅ Python 3.13 built with max optimizations! Output at: $PREFIX_USR"

# 🎯 Strip binaries (reduce size)
find $PREFIX_USR -type f \( -perm -111 -o -name "*.so" \) -exec strip --strip-unneeded {} +

#####################################
# 📦 Create .deb package 📦
#####################################

echo "📦 Creating DEB package for Termux..."

PKG_NAME="python3.13"
PKG_VERSION="$PYTHON_VERSION"
ARCH="aarch64"
DEB_DIR="$PWD/${PKG_NAME}_$PKG_VERSION"

# 1. Create DEB folder structure
rm -rf $DEB_DIR
mkdir -p $DEB_DIR/DEBIAN
mkdir -p $DEB_DIR/data/data/com.termux/files/usr

# 2. Copy compiled files
cp -a $PREFIX_USR/* $DEB_DIR/data/data/com.termux/files/usr/

# 3. Create control file
cat > $DEB_DIR/DEBIAN/control <<EOF
Package: $PKG_NAME
Version: $PKG_VERSION
Architecture: $ARCH
Maintainer: Cross-compiled by Shoaib Hassan
Description: Highly optimized Python 3.13 cross-compiled for Termux aarch64.
EOF

# 4. Create empty postinst script
cat > $DEB_DIR/DEBIAN/postinst <<EOF
#!/bin/bash
EOF

# 5. Set correct permissions
chmod 0755 $DEB_DIR/DEBIAN
chmod 0644 $DEB_DIR/DEBIAN/control
chmod 0755 $DEB_DIR/DEBIAN/postinst

# 6. Build .deb package
dpkg-deb --build $DEB_DIR

echo "✅ DEB package created: ${DEB_DIR}.deb"
