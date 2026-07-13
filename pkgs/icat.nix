{ lib
, stdenv
, fetchurl
, _7zz
, asar
, icoutils
, makeWrapper
, makeDesktopItem
, copyDesktopItems
, electron
, ffmpeg
}:

let
  info = lib.importJSON ./version.json;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "icat";
  version = info.version;

  # Официальный установщик из S3-бакета автообновлятора ICAT;
  # sha512 берётся из latest.yml того же бакета (см. scripts/update.sh)
  src = fetchurl {
    url = "https://icat-public-releases.s3.amazonaws.com/ICAT-${info.version}.exe";
    hash = info.sha512;
  };

  nativeBuildInputs = [ _7zz asar icoutils makeWrapper copyDesktopItems ];

  desktopItems = [
    (makeDesktopItem {
      name = "icat";
      desktopName = "NVIDIA ICAT";
      genericName = "Image and video comparison";
      comment = "Compare multiple videos and images side by side";
      exec = "icat";
      icon = "icat";
      categories = [ "Graphics" "AudioVideo" "Viewer" ];
      startupWMClass = "icat";
    })
  ];

  # src — NSIS-установщик: первая ступень достаёт app-64.7z, вторая — сам app
  unpackPhase = ''
    runHook preUnpack
    7zz x -y -oinstaller "$src"
    7zz x -y -oapp 'installer/$PLUGINSDIR/app-64.7z'
    asar extract app/resources/app.asar unpacked
    runHook postUnpack
  '';

  postPatch = ''
    # ffmpeg: вместо виндового бинаря из resources/bin — системный с libsvtav1
    substituteInPlace unpacked/build/icat/electron/main.js \
      --replace-fail \
        "var ffmpegPath = electron_1.app.isPackaged ? (0, path_1.join)(process.resourcesPath, 'bin', 'ffmpeg', 'ffmpeg.exe') : (0, path_1.join)(__dirname, '..', '..', '..', 'bin', 'ffmpeg', 'ffmpeg.exe');" \
        "var ffmpegPath = '${lib.getExe ffmpeg}';"

    # автообновлятор смотрит в S3 с Windows-билдами — на Linux бессмыслен
    substituteInPlace unpacked/build/icat/electron/main.js \
      --replace-fail "electron_updater_1.autoUpdater.checkForUpdates();" ";" \
      --replace-fail "mainWindow.webContents.openDevTools();" ";"
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/icat
    cp -r unpacked $out/share/icat/app

    # иконки: вытаскиваем 32-битные PNG всех размеров из ico
    icotool -x installer/uninstallerIcon.ico -o .
    for f in uninstallerIcon_*x32.png; do
      size=$(echo "$f" | sed -E 's/.*_([0-9]+)x[0-9]+x32\.png/\1/')
      install -Dm644 "$f" "$out/share/icons/hicolor/''${size}x''${size}/apps/icat.png"
    done

    # --disable-gpu-sandbox: иначе на NVIDIA GPU-процесс молча умирает и всё
    #   рендерится SwiftShader'ом на CPU
    # --max-active-webgl-contexts=64: ICAT держит WebGL-контекст на изображение,
    #   дефолтный лимит 16 даёт карусель context-loss при 16+ картинках
    # CHROME_DESKTOP: сопоставляет Wayland app_id окна с icat.desktop
    makeWrapper ${lib.getExe electron} $out/bin/icat \
      --add-flags $out/share/icat/app \
      --add-flags "--disable-gpu-sandbox" \
      --add-flags "--max-active-webgl-contexts=64" \
      --add-flags "--ozone-platform-hint=auto" \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg ]} \
      --set-default CHROME_DESKTOP icat.desktop

    runHook postInstall
  '';

  meta = {
    description = "NVIDIA ICAT — image and video comparison & analysis tool (unofficial Linux repackaging)";
    homepage = "https://www.nvidia.com/en-us/geforce/technologies/icat/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "icat";
  };
})
