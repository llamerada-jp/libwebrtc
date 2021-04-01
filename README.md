# libwebrtc for DataChannel
It is a building program of WebRTC native library from Chromium. This building program configured for only enable DataChannel without multimedia features. The purpose of this repository is making easy to use WebRTC native library by sharing pre-compiled libraries.

Build sequence of program is based on below documents.

http://webrtc.github.io/webrtc-org/native-code/development/

This program automatically uses the latest stable version of WebRTC's source code.

## Requirements

- golang 1.13 or later
- Other requirement environments are depend on [`Chromium project`](https://chromium.googlesource.com/chromium/src/+/master/docs/linux/build_instructions.md)

## How to use

### Build and test for linux with amd64

At amd64 linux environment.

```sh
go run . build
go run . test
```

There is an archive file in `opt/linux_amd64`.

### Build and test for linux with i386

At amd64 linux environment.

```sh
sudo apt install qemu-user-static g++-i686-linux-gnu

go run . build --arch=i386
go run . test --arch=i386
```

There is an archive file in `opt/linux_i386`.

### Build and test for linux with armhf

At amd64 linux environment.

```sh
sudo apt install qemu-user-static g++-arm-linux-gnueabihf
sudo ln -s /usr/arm-linux-gnueabihf/lib/ld-2.*.so /lib/ld-linux-armhf.so.3

go run . build --arch=armhf
LD_LIBRARY_PATH=/usr/arm-linux-gnueabihf/lib go run . test --arch=armhf
```

There is an archive file in `opt/linux_armhf`.

### Build and test for linux with arm64

At amd64 linux environment.

```sh
sudo apt install qemu-user-static g++-aarch64-linux-gnu
sudo ln -s /usr/aarch64-linux-gnu/lib/ld-2.*.so /lib/ld-linux-aarch64.so.1

go run . build --arch=arm64
LD_LIBRARY_PATH=/usr/aarch64-linux-gnu/lib go run . test --arch=arm64
```

There is an archive file in `opt/linux_arm64`.

### Build and test for macos

At macos environment.

```sh
go run . build
go run . test
```

There is an archive file in `opt/macos_amd64`.

## Configuration

There are configuration files in `configs/`.
You can customize the build option by editing files in `configs/`.

#### ChromeOsStr

A string used to match the operating system of the following sites.
This option is ignored without linux.

https://omahaproxy.appspot.com/

#### BuildDepsOpts

Options for [`install-build-deps.sh`](https://chromium.googlesource.com/chromium/src/+/master/build/install-build-deps.sh).

#### GnOpts

Options for GN build configuration tool.
You can find help on the following pages

https://www.chromium.org/developers/gn-build-configuration

If you want more configuration, you can run the following command to get a list of options after executing the build once.

```
cd opt/linux_amd64/src
../../depot_tools/gn args out/Default/ --list
```

#### Headers, HeadersWithSubdir

Source list of header files to be archived.
The official list can be found on the following pages, but that's not enough.

https://webrtc.googlesource.com/src/+/master/native-api.md

## License
License follows original sources of it. See below documents.

https://webrtc.org/support/license
