FROM debian:testing

include(debian.m4)
include(boost-1.59.0.m4)
include(buildbot.m4)

RUN apt-get update && \
  apt-get install -y --no-install-recommends cmake file m4 less vim \
    clang cpio bison flex xz-utils libfuse-dev libxml2-dev libicu-dev \
    libssl-dev libbz2-dev zlib1g-dev libudev-dev libtool automake \
    liblzma-dev uuid-dev llvm-dev

# Make specalized 7zip
#RUN git clone --depth=1 https://github.com/tpoechtrager/p7zip.git
#RUN cd p7zip &&\
#  make 7z -j$(grep -c ^processor /proc/cpuinfo) &&\
#  make install

# Bulid & install Darling
RUN git clone  --depth=1 --recursive https://github.com/darlinghq/darling.git
RUN cd darling &&\
  sed -i 's/#include <bootfiles.h>/#include <ctype.h>\n#include <signal.h>/' \
    src/launchd/support/launchctl.c &&\
  mkdir -p build/x86-64 &&\
  cd build/x86-64 &&\
  cmake ../.. -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_TOOLCHAIN_FILE=../../Toolchain-x86_64.cmake &&\
  make -j$(grep -c ^processor /proc/cpuinfo) &&\
  make install -j$(grep -c ^processor /proc/cpuinfo)

# Install OSX SDK
# Get Xcode from here: https://developer.apple.com/downloads/?name=Xcode
ENV TARGET=x86_64-apple-darwin15
ADD MacOSX10.11.sdk.tar.bz2 .
RUN mv MacOSX10.11.sdk /$TARGET

# Build and install xar
RUN git clone --depth=1 https://github.com/mackyle/xar.git
RUN cd xar/xar &&\
  ./autogen.sh &&\
  ./configure --prefix=/usr &&\
  make -j$(grep -c ^processor /proc/cpuinfo) &&\
  make install

# Build and install cctools
RUN git clone --depth=1 https://github.com/tpoechtrager/cctools-port.git
RUN cd cctools-port/cctools &&\
  ./autogen.sh &&\
  ./configure --prefix=/$TARGET/usr --target=$TARGET --disable-clang-as &&\
  make -j$(grep -c ^processor /proc/cpuinfo) &&\
  make install -j$(grep -c ^processor /proc/cpuinfo)

# Create fake dsymutil
RUN ln -s /bin/true /$TARGET/usr/bin/dsymutil

# Configure target PATH
ENV PATH=/$TARGET/usr/bin:$PATH

# Build gcc cross compiler
ENV GCC_VERSION=5.3.0
RUN wget --quiet \
  https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2
RUN tar xf gcc-$GCC_VERSION.tar.bz2 && rm gcc-$GCC_VERSION.tar.bz2
RUN cd gcc-$GCC_VERSION && ./contrib/download_prerequisites > /dev/null
RUN cd gcc-$GCC_VERSION && \
  mkdir build && \
  cd build && \
  ../configure --with-ld=/$TARGET/usr/bin/${TARGET}-ld \
    --with-as=/$TARGET/usr/bin/${TARGET}-as --target=${TARGET} \
    --enable-languages=c,c++ --disable-nls --enable-multilib \
    --with-multilib-list=m32,m64 --enable-checking=release --without-headers \
    -enable-lto --disable-libstdcxx-pch --with-system-zlib \
    --with-sysroot=/$TARGET --prefix=/$TARGET/usr && \
  make -j$(grep -c ^processor /proc/cpuinfo) && \
  make install

RUN echo "\nalias ls='ls --color'" >> $HOME/.bashrc
