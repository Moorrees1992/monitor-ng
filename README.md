# multimon-ng

![Demo](demo/demo.webp)

multimon-ng is the successor of multimon. It decodes the following digital transmission modes:

- POCSAG512 POCSAG1200 POCSAG2400
- FLEX FLEX_NEXT
- EAS
- UFSK1200 CLIPFSK FMSFSK AFSK1200 AFSK2400 AFSK2400_2 AFSK2400_3
- HAPN4800
- FSK9600
- DTMF
- ZVEI1 ZVEI2 ZVEI3 DZVEI PZVEI
- EEA EIA CCIR
- MORSE_CW
- DUMPCSV X10 SCOPE SDL_SCOPE
- GSC (Golay Sequential Code)

## Building

multimon-ng is built using CMake.

### Prerequisites

Required:
- A C compiler (GCC or Clang)
- CMake 3.15 or newer
- `make` (or another CMake-supported generator)

Optional (auto-detected):
- `libpulse-dev` — enables PulseAudio live audio input
- `libx11-dev` — enables the X11 scope display
- SDL3 — enables the SDL3 digital phosphor scope

If none of the audio libraries are found, multimon-ng is built with file/stdin
input only (`DUMMY_AUDIO`). This is fine for processing recorded samples or
piped input from tools like `rtl_fm`.

Example (Debian/Ubuntu):
```
sudo apt-get install build-essential cmake libpulse-dev libx11-dev
```

### Build

```
cmake -S . -B build
cmake --build build --parallel 4
sudo cmake --install build
```

The default install prefix is `/usr/local`. To install elsewhere (for example,
system-wide at `/usr` or into your user directory), pass `CMAKE_INSTALL_PREFIX`:
```
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr
```

## Docker

The Docker image is a headless build intended for files and standard input.
PulseAudio, X11, and SDL3 support are disabled. SoX is included for WAV, FLAC,
MP3, OGG, and other supported file formats.

Build the image (the test suite runs as part of the build):

```sh
docker build -t multimon-ng .
```

Decode a mounted file:

```sh
docker run --rm \
  -v "$(pwd)/test/samples:/samples:ro" \
  multimon-ng -q -a POCSAG512 /samples/POCSAG_sample_-_512_bps.flac
```

Pipe raw 16-bit, single-channel samples at 22050 Hz through standard input:

```sh
rtl_fm -f 403600000 -s 22050 \
  | docker run --rm -i multimon-ng -t raw -a FMSFSK -a AFSK1200 -
```

With no arguments the container reads raw samples from standard input. To use
the included signal generator, override the entrypoint:

```sh
docker run --rm --entrypoint gen-ng multimon-ng -t raw -d "123" - | wc -c
```

### Gitea Container Registry

The workflow in `.gitea/workflows/docker.yml` builds and tests pull requests.
Pushes to `master` and tags matching `v*` are also published to the Container
Registry of the Gitea instance. Configure these Actions secrets:

- `REGISTRY_USER`: the Gitea user that publishes the package
- `REGISTRY_TOKEN`: a personal access token with package write access

Images pushed from `master` receive `latest` and `sha-<commit>` tags. A stable
tag such as `v1.6.0` produces `1.6.0`, `1.6`, `1`, and `sha-<commit>` tags.

### GitHub Container Registry

The workflow in `.github/workflows/docker.yml` provides the same build, tests,
and runtime smoke test on GitHub-hosted runners. Pull requests only build and
test. Pushes to `master` and tags matching `v*` publish to
`ghcr.io/<owner>/<repository>`.

No custom secrets or self-hosted runner are required. The workflow grants the
automatically provided `GITHUB_TOKEN` `packages: write` permission. Images from
`master` receive `latest` and `sha-<commit>` tags; stable version tags receive
the same semantic-version tags as the Gitea workflow.

### Windows MinGW Builds

#### On Windows (MSYS2/MinGW)
Install MSYS2, then from the MinGW64 or MinGW32 shell:
```
cmake -S . -B build
cmake --build build --parallel 4
```

#### Cross-compiling from Linux
Install the MinGW cross-compiler, then use the provided toolchain files:
```
# For 64-bit Windows
cmake -S . -B build-mingw64 -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-mingw64.cmake
cmake --build build-mingw64 --parallel 4

# For 32-bit Windows
cmake -S . -B build-mingw32 -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-mingw32.cmake
cmake --build build-mingw32 --parallel 4
```

## Supported Environments

So far multimon-ng has been successfully built on:

- Arch Linux
- Debian
- Gentoo
- Kali Linux
- Ubuntu
- macOS
- Windows (MSYS2/MinGW, Cygwin, and VisualStudio/MSVC)
- FreeBSD

## Examples

### Wav to raw

Files can be easily converted into multimon-ng's native raw format using *sox*. e.g:

    sox -R -t wav pocsag_short.wav -esigned-integer -b16 -r 22050 -t raw pocsag_short.raw

GNURadio can also generate the format using the file sink in input mode *short*. 

### Pipe sox to multimon-ng

You can also "pipe" raw samples into multimon-ng using something like:

    sox -R -t wav pocsag_short.wav -esigned-integer -b16 -r 22050 -t raw - | ./multimon-ng -

> [!NOTE]
> Note the trailing dash, means write/read to/from stdin

### Pipe rtl_fm to multimon-ng

As a last example, here is how you can use it in combination with RTL-SDR:

    rtl_fm -f 403600000 -s 22050 | multimon-ng -t raw -a FMSFSK -a AFSK1200 /dev/stdin

### Flac record and parse live data

A more advanced sample that combines `rtl_fm`, `flac`, and `tee` to split the output from `rtl_rm` into separate streams. One stream to be passed to `flac` to record the audio and another stream to for example an application that does text parsing of `mulimon-ng` output



```sh
rtl_fm -s 22050 -f 123.456M -g -9.9 | tee >(flac -8 --endian=little --channels=1 --bps=16 --sample-rate=22050 --sign=signed - -o ~/recordings/rtlfm.$EPOCHSECONDS.flac -f) | multimon-ng -v 0 -a FLEX -a FLEX_NEXT -t raw /dev/stdin
```

1. You can pass `-l` to `rtl_fm` for the squelch level, this will cut the noise floor so less data gets encoded by flac and will significantly reduce the file size but could result in loss of signal data. **This value must be tuned!**
2. Flac uses `-8` here, if you run an a resource constraint device you may want to lower this value
3. The Flac `-o` argument value contains `$EPOCHSECONDS` to make unique files when this gets restarted

To replay the recorded flac file to multimon-ng (requires sox):

```sh
flac -d --stdout ~/recordings/rtlf/rtlfm.1725033204.flac | multimon-ng -r -v 0 -a FLEX_NEXT -t flac -
```

## Packaging

To stage an install into a packaging directory (typical for distribution
packaging), use the standard `DESTDIR` variable:

```
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build --parallel 4
DESTDIR=/path/to/pkgroot cmake --install build
```

`DESTDIR` is prepended to the install paths, so files land under
`/path/to/pkgroot/usr/bin/multimon-ng`, etc.

## Testing

After building, run the test suite:

```
./test/run_tests.sh
```

> [!NOTE]
> Testing non-raw sample files (flac, wav) requires [SoX](https://sourceforge.net/projects/sox/) to be installed.
