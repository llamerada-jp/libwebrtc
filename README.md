# libwebrtc
It is a build program of WebRTC native library from Chromium. The purpose of this repository is making easy to use WebRTC native library by sharing pre-compiled libraries.

Build sequence of program is based on below documents.

http://webrtc.github.io/webrtc-org/native-code/development/

This program automatically uses the latest stable version of WebRTC's source code.

## How to use

### Build and test for linux with amd64

```sh
go run . build
go run . test
```

There is an archive file in `opt/linux_amd64`.

### Build and test for linux with i386

```sh
sudo apt install qemu-usr-static g++-i686-linux-gnu

go run . build --arch=i386
go run . test --arch=i386
```

There is an archive file in `opt/linux_i386`.

### Build and test for linux with armhf

```sh
sudo apt install qemu-usr-static g++-arm-linux-gnueabihf

sudo ln -s /usr/arm-linux-gnueabihf/lib /lib/arm-linux-gnueabihf
sudo ln -s /lib/arm-linux-gnueabihf/ld-2.*.so /lib/ld-linux-armhf.so.3

go run . build --arch=armhf
go run . test --arch=armhf
```

There is an archive file in `opt/linux_armhf`.

### Build and test for linux with arm64

```sh
sudo apt install qemu-usr-static g++-aarch64-linux-gnu

sudo ln -s /usr/aarch64-linux-gnu/lib/ /lib/aarch64-linux-gnu
sudo ln -s /lib/aarch64-linux-gnu/ld-2.23.so /lib/ld-linux-aarch64.so.1

go run . build --arch=arm64
go run . test --arch=arm64
```

There is an archive file in `opt/linux_arm64`.

## Configuration

There are configuration files in `configs/`.
You can customize the build option by editing files in `configs/`.

#### ChromeOsStr

A string used to match the operating system of the following sites.

https://omahaproxy.appspot.com/

#### BuildDepsOpts

Options for [`install-build-deps.sh`](https://chromium.googlesource.com/chromium/src/+/master/build/install-build-deps.sh).

#### GnOpts

#### Headers, HeadersWithSubdir

Source list of header files to be archived.
The official list can be found on the following pages, but that's not enough.

https://webrtc.googlesource.com/src/+/master/native-api.md

## License
License follows original sources of it. See below documents.

https://webrtc.org/support/license
