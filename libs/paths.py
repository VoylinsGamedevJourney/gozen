#!/usr/bin/env python3

from pathlib import Path
from typing import Any

LIBS_ROOT_DIR = Path(__file__).parent.resolve()

# FFmpeg
FFMPEG_SOURCE_DIR: Path = LIBS_ROOT_DIR / "ffmpeg"


def get_ffmpeg_install_dir(target_platform: str) -> Path:
    return LIBS_ROOT_DIR / "ffmpeg" / f"bin_{target_platform}"


def get_lib_dir(install_dir: Path) -> Path:
    assert install_dir.exists(), f"Install directory {install_dir} does not exist"

    libdir = next((d for d in install_dir.glob("lib*/")), None)
    if libdir is None:
        raise FileNotFoundError(f"Could not find lib directory in {install_dir}")

    return libdir


# FFmpeg dependencies
X264_REPO = "https://code.videolan.org/videolan/x264.git"
X264_SOURCE_DIR = LIBS_ROOT_DIR / "x264_src"
X264_INSTALL_DIR_NAME = "x264"
X264_GIT_OPTIONS: dict[str, Any] = {}

X265_REPO = "https://bitbucket.org/multicoreware/x265_git.git"
X265_SOURCE_DIR = LIBS_ROOT_DIR / "x265_src"
X265_INSTALL_DIR_NAME = "x265"
X265_BUILD_DIR = X265_SOURCE_DIR / "build"
X265_GIT_OPTIONS: dict[str, Any] = {}

AOM_REPO = "https://aomedia.googlesource.com/aom"
AOM_SOURCE_DIR = LIBS_ROOT_DIR / "aom_src"
AOM_INSTALL_DIR_NAME = "aom"
AOM_BUILD_DIR = AOM_SOURCE_DIR.parent / "aom_build"
AOM_GIT_OPTIONS: dict[str, Any] = {}

SVT_AV1_REPO = "https://gitlab.com/AOMediaCodec/SVT-AV1.git"
SVT_AV1_SOURCE_DIR = LIBS_ROOT_DIR / "svtav1_src"
SVT_AV1_INSTALL_DIR_NAME = "svtav1"
SVT_AV1_BUILD_DIR = SVT_AV1_SOURCE_DIR / "Build"
SVT_AV1_GIT_OPTIONS: dict[str, Any] = {"--branch": "v2.3.0"}

VPX_REPO = "https://chromium.googlesource.com/webm/libvpx"
VPX_SOURCE_DIR = LIBS_ROOT_DIR / "vpx_src"
VPX_INSTALL_DIR_NAME = "vpx"
VPX_GIT_OPTIONS: dict[str, Any] = {}

OPUS_REPO = "https://gitlab.xiph.org/xiph/opus.git"
OPUS_SOURCE_DIR = LIBS_ROOT_DIR / "opus_src"
OPUS_INSTALL_DIR_NAME = "opus"
OPUS_GIT_OPTIONS: dict[str, Any] = {}

OGG_REPO = "https://gitlab.xiph.org/xiph/ogg.git"
OGG_SOURCE_DIR = LIBS_ROOT_DIR / "ogg_src"
OGG_INSTALL_DIR_NAME = "ogg"
OGG_GIT_OPTIONS: dict[str, Any] = {"--branch": "v1.3.5"}

VORBIS_REPO = "https://gitlab.xiph.org/xiph/vorbis.git"
VORBIS_SOURCE_DIR = LIBS_ROOT_DIR / "vorbis_src"
VORBIS_INSTALL_DIR_NAME = "vorbis"
VORBIS_GIT_OPTIONS: dict[str, Any] = {"--branch": "v1.3.7"}

MP3LAME_REPO = "https://svn.code.sf.net/p/lame/svn/trunk/lame"
MP3LAME_SOURCE_DIR = LIBS_ROOT_DIR / "mp3lame_src"
MP3LAME_INSTALL_DIR_NAME = "mp3lame"
MP3LAME_GIT_OPTIONS: dict[str, Any] = {"svn": True, "-r": "6525"}
