{
  lib,
  stdenv,

  version,

  gde_gozen,
  godot_4_7,
  ffmpeg-full,
  makeBinaryWrapper,
}:
let
  godot = godot_4_7;
  preset = "Linux_x86_64";
in
stdenv.mkDerivation {
  pname = "gozen";

  inherit version;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./src
    ];
  };

  nativeBuildInputs = [
    godot
    makeBinaryWrapper
  ];

  buildInputs = [
    gde_gozen
    ffmpeg-full
  ];

  preBuild = ''
    cp -dr ${gde_gozen}/lib ./bin
  '';

  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)

    mkdir -p $HOME/.local/share/godot/
    ln -s "${godot.export-template}"/share/godot/export_templates "$HOME"/.local/share/godot/

    godot --headless --path ./src --export-release ${preset} ../gozen

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/gozen
    cp ./gozen $out/libexec/gozen/gozen

    mkdir -p $out/libexec/bin
    cp -dr ${gde_gozen}/lib/* $out/libexec/bin

    # Wrap because Godot requires GDExtension to be a relative path of the binary
    mkdir -p $out/bin
    makeWrapper $out/libexec/gozen/gozen $out/bin/gozen \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ ffmpeg-full ]}"

    runHook postInstall
  '';

  meta = {
    description = "The Minimalist Video Editor";
    homepage = "https://gozen.voylin.com/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "gozen";
  };
}
