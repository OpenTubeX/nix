# OpenTubeX Nix packages

This repository packages the official
[OpenTubeX](https://github.com/OpenTubeX/OpenTubeX) releases for NixOS, Linux,
and macOS. It provides a Nix flake and overlay, using the release binaries
with their bundled Electron runtime.

| Platform | Architectures |
| --- | --- |
| NixOS and Linux | `x86_64-linux`, `aarch64-linux` |
| macOS | `x86_64-darwin` for Intel, `aarch64-darwin` for Apple Silicon |

## Install OpenTubeX

Install [Nix](https://nixos.org/download/) and enable `nix-command` and
`flakes`. For a standalone Nix installation, add this to
`~/.config/nix/nix.conf`:

```conf
experimental-features = nix-command flakes
```

Then install OpenTubeX in your user profile:

```sh
nix profile install github:OpenTubeX/nix#opentubex
opentubex
```

To run it without adding it to your profile:

```sh
nix run github:OpenTubeX/nix#opentubex
```

The Linux package includes desktop icons and the `opentubex://` URL handler.
Its launcher supplies Nix-built FFmpeg, FFprobe, and yt-dlp. On macOS, the
package includes `Applications/OpenTubeX.app` and the `opentubex` command,
preserving the release's ad-hoc signature.

### Declarative installation

Add this input to your existing configuration flake:

```nix
inputs.opentubex.url = "github:OpenTubeX/nix";
```

Pass your flake inputs to your NixOS or nix-darwin modules with
`specialArgs = { inherit inputs; };`, then add a module like this:

```nix
{ inputs, pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = [
    inputs.opentubex.packages.${pkgs.stdenv.hostPlatform.system}.opentubex
  ];
}
```

For standalone Home Manager, pass `extraSpecialArgs = { inherit inputs; };`
and use `home.packages` instead of `environment.systemPackages`.

An overlay is also available as `inputs.opentubex.overlays.default`. Adding it
to `nixpkgs.overlays` exposes `pkgs.opentubex` using your own Nixpkgs version.
The package outputs above use this repository's tested Nixpkgs pin.

## Update OpenTubeX

For the profile installation above:

```sh
nix profile upgrade opentubex
```

If you installed the default output without `#opentubex`, check
`nix profile list` and use the name shown there.

For a declarative installation, update the input from your configuration
directory and rebuild your NixOS, nix-darwin, or Home Manager configuration:

```sh
nix flake update opentubex
```

New releases are pinned automatically in this repository. Existing
installations update when you run the commands above. There is currently no
nightly package channel.

Intel Mac support uses Nixpkgs 26.05, the last Nixpkgs release supporting
`x86_64-darwin`. Keep that constraint in mind when overriding the Nixpkgs
input or using the overlay.

## How publishing works

After an OpenTubeX release is published, the application repository sends an
`opentubex-release` repository dispatch containing the exact release tag.
The **Build and update Nix packages** workflow can also be run manually with
an optional `releaseTag`. Without a tag, it selects the latest published
release.

For a release update, the workflow:

1. records the release version, asset names, and SHA-256 digests in
   `release.json`;
2. builds the packages and checks the bundled runtime on native runners for
   all four platforms, verifying each downloaded asset against its digest;
3. verifies both macOS bundle signatures;
4. publishes the new pin in a GitHub-signed commit only after all builds and
   checks pass, provided the tested branch revision has not changed.

## Maintainer setup

Enable GitHub Actions in this repository. The workflow uses the built-in
`GITHUB_TOKEN`, with write access limited to the publishing job. Manual
updates need no additional secrets, signing keys, or binary cache. The
OpenTubeX application repository uses its existing `PUSH_TOKEN` secret to
send cross-repository dispatches. That token needs write access to this
repository.

To prepare and check an update locally, install Python 3, the
[GitHub CLI](https://cli.github.com/), and Nix, then run:

```sh
python3 scripts/update.py
python3 -m unittest discover -s scripts -v
nix fmt -- --check flake.nix package.nix
nix flake check --no-build --all-systems
nix build .#opentubex --print-build-logs
```

Use `python3 scripts/update.py --tag v0.34.1-beta` to select a particular
published release. The local build checks the host platform; CI checks all
four platforms before an automated release update is published.
