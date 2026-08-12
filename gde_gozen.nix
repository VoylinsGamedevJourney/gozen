{
  lib,
  stdenv,

  version,

  scons,
  python3,
  autoPatchelfHook,
  ffmpeg-full,
}:
stdenv.mkDerivation {
  pname = "gde-gozen";
  inherit version;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./core
    ];
  };

  nativeBuildInputs = [
    scons
    python3
    autoPatchelfHook
  ];

  buildInputs = [ ffmpeg-full ];

  preBuild = ''
    cd ./core

    mkdir -p ./ffmpeg/bin_linux

    cp -dr ${ffmpeg-full.dev}/include ./ffmpeg/bin_linux/include
    cp -dr ${ffmpeg-full.lib}/lib ./ffmpeg/bin_linux/lib
  '';

  buildPhase = ''
    runHook preBuild

    scons \
      -j$NIX_BUILD_CORES \
      platform=linux \
      arch=x86_64 \
      target=template_release \
      use_system=yes

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -r ../bin/* $out/lib/

    runHook postInstall
  '';

  meta = {
    description = "Video playback addon for the Godot game engine";
    homepage = "https://gozen.voylin.com/";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}
