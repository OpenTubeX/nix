{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  unzip,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  gtk4,
  nss,
  nspr,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxkbfile,
  pango,
  pciutils,
  systemd,
  libnotify,
  pipewire,
  libsecret,
  libpulseaudio,
  libdrm,
  libgbm,
  libxkbcommon,
  libxshmfence,
  libGL,
  vulkan-loader,
  xdg-utils,
  desktop-file-utils,
  ffmpeg,
  yt-dlp,
}:
let
  release = builtins.fromJSON (builtins.readFile ./release.json);
  system = stdenv.hostPlatform.system;
  source = release.sources.${system} or (throw "OpenTubeX does not support ${system}");
  linuxLibraries = [
    alsa-lib
    at-spi2-atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    gtk4
    nss
    nspr
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxkbfile
    pango
    pciutils
    stdenv.cc.cc
    systemd
    libnotify
    pipewire
    libsecret
    libpulseaudio
    libdrm
    libgbm
    libxkbcommon
    libxshmfence
    libGL
    vulkan-loader
  ];
in
stdenv.mkDerivation {
  pname = "opentubex";
  inherit (release) version;
  src = fetchurl {
    url = "https://github.com/OpenTubeX/OpenTubeX/releases/download/${release.tag}/${source.name}";
    inherit (source) hash;
  };

  strictDeps = true;
  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;
  # Preserve the upstream ad-hoc signatures and bundle contents on macOS.
  dontFixup = stdenv.hostPlatform.isDarwin;
  dontWrapGApps = true;

  nativeBuildInputs =
    if stdenv.hostPlatform.isDarwin then
      [ unzip ]
    else
      [
        dpkg
        autoPatchelfHook
        makeWrapper
        wrapGAppsHook3
        desktop-file-utils
      ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux linuxLibraries;

  unpackPhase = ''
    runHook preUnpack
  ''
  + (
    if stdenv.hostPlatform.isDarwin then
      ''
        unzip -q "$src"
      ''
    else
      ''
        dpkg-deb -x "$src" .
      ''
  )
  + ''
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
  ''
  + (
    if stdenv.hostPlatform.isDarwin then
      ''
        mkdir -p "$out/Applications"
        cp -R OpenTubeX.app "$out/Applications/"
        ln -s "$out/Applications/OpenTubeX.app/Contents/MacOS/OpenTubeX" "$out/bin/opentubex"
      ''
    else
      ''
        mkdir -p "$out/lib/opentubex" "$out/share"
        cp -a opt/OpenTubeX/. "$out/lib/opentubex/"
        cp -a usr/share/applications usr/share/icons "$out/share/"
        substituteInPlace "$out/share/applications/opentubex.desktop" \
          --replace-fail /opt/OpenTubeX/opentubex "$out/bin/opentubex"
        # Nix cannot install a root-owned setuid helper. Electron uses its user namespace sandbox.
        rm "$out/lib/opentubex/chrome-sandbox"
      ''
  )
  + ''
    runHook postInstall
  '';

  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    makeWrapper "$out/lib/opentubex/opentubex" "$out/bin/opentubex" \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${
        lib.makeBinPath [
          xdg-utils
          ffmpeg
          yt-dlp
        ]
      } \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath linuxLibraries}
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x "$out/bin/opentubex"
  ''
  + (
    if stdenv.hostPlatform.isDarwin then
      ''
        test -s "$out/Applications/OpenTubeX.app/Contents/Resources/app.asar"
      ''
    else
      ''
        test -s "$out/lib/opentubex/resources/app.asar"
        desktop-file-validate "$out/share/applications/opentubex.desktop"
      ''
  )
  + ''
    runHook postInstallCheck
  '';

  meta = {
    description = "A customizable, privacy-focused YouTube client";
    homepage = "https://opentubex.org";
    changelog = "https://github.com/OpenTubeX/OpenTubeX/releases/tag/${release.tag}";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames release.sources;
    mainProgram = "opentubex";
  };
}
