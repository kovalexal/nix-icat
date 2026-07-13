# nix-icat

**NVIDIA ICAT** ([Image Comparison & Analysis Tool](https://www.nvidia.com/en-us/geforce/technologies/icat/)) repackaged to run **natively on Linux / NixOS** — no Wine involved.

ICAT is an Electron application. This flake takes the official Windows installer, extracts the (platform-independent) application code, applies a few Linux-specific fixes and runs it with Electron and FFmpeg from nixpkgs.

## Quick start

```console
$ nix run github:kovalexal/nix-icat
```

## Installation (NixOS flake)

Add the input to your `flake.nix`:

```nix
inputs.nix-icat.url = "github:kovalexal/nix-icat";
```

Then either install the package directly:

```nix
environment.systemPackages = [
  inputs.nix-icat.packages.${pkgs.system}.icat
];
```

or use the overlay:

```nix
nixpkgs.overlays = [ inputs.nix-icat.overlays.default ];
environment.systemPackages = [ pkgs.icat ];
```

The application appears in your desktop menu as **NVIDIA ICAT**, with proper icons and Wayland `app_id` ↔ desktop-file matching.

> **Note on licensing:** ICAT is proprietary NVIDIA software (`meta.license = unfree`). This flake enables `allowUnfree` for its own outputs, so no extra configuration is needed. The installer is downloaded at build time from NVIDIA's official release bucket — no NVIDIA binaries are redistributed by this repository.

## Why native instead of Wine?

Running the Windows build under Wine suffers from broken HiDPI scaling and non-working drag-and-drop. Running natively fixes both — but needs the following, which this package applies for you:

| Fix | Why |
|---|---|
| `--disable-gpu-sandbox` | On NVIDIA systems Chromium's GPU-process sandbox can kill the GPU process silently, dropping the whole app to SwiftShader software rendering (unusably slow, ~100% CPU). |
| `--max-active-webgl-contexts=64` | ICAT creates one WebGL context per image. Chromium's default limit is ~16 active contexts, after which contexts get force-evicted — with 16+ images this causes a context-loss storm: white flashes, constant texture re-uploads, unresponsive UI. On Windows ICAT uses WebGPU and never hits this. |
| `--ozone-platform-hint=auto` | Native Wayland when available: correct fractional scaling and drag-and-drop. |
| System `ffmpeg` in `PATH`, patched into the app | Video export encodes via SVT-AV1 by spawning an ffmpeg binary; the bundled one is a Windows exe. |
| Auto-updater disabled | The built-in electron-updater points at Windows builds; updates are handled by this flake instead. |

## Known limitations

- **HEVC/H.265 playback** likely does not work (Chromium on Linux has no built-in HEVC decoding). H.264 / VP9 / AV1 and all image formats work fine.
- ICAT writes error logs to `~/.config/icat/error_logs/` and never cleans them up.

## Updates

A daily GitHub Action checks NVIDIA's official release feed (the same S3 bucket the app's own auto-updater uses) and opens a PR when a new version is published. `flake.lock` (Electron, FFmpeg) is refreshed weekly by a separate action.

To check manually:

```console
$ nix run .#update
```

## Disclaimer

This is an unofficial repackaging, not affiliated with or endorsed by NVIDIA. All rights to ICAT belong to NVIDIA Corporation.
