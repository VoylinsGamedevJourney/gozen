#!/usr/bin/env python3

from pathlib import Path
from typing import Any


# FFmpeg
FFMPEG_SOURCE_DIR = Path("ffmpeg").absolute()


def get_ffmpeg_install_dir(target_platform: str) -> Path:
    return (Path("ffmpeg") / f"bin_{target_platform}").absolute()


# FFmpeg dependencies
X264_REPO = "https://code.videolan.org/videolan/x264.git"
X264_SOURCE_DIR = Path("x264_src").absolute()
X264_INSTALL_DIR_NAME = "x264"
X264_GIT_OPTIONS: dict[str, Any] = {}

X265_REPO = "https://bitbucket.org/multicoreware/x265_git.git"
X265_SOURCE_DIR = Path("x265_src").absolute()
X265_INSTALL_DIR_NAME = "x265"
X265_BUILD_DIR = X265_SOURCE_DIR / "build"
X265_GIT_OPTIONS: dict[str, Any] = {}

AOM_REPO = "https://aomedia.googlesource.com/aom"
AOM_SOURCE_DIR = Path("aom_src").absolute()
AOM_INSTALL_DIR_NAME = "aom"
AOM_BUILD_DIR = AOM_SOURCE_DIR.parent / "aom_build"
AOM_GIT_OPTIONS: dict[str, Any] = {}

SVT_AV1_REPO = "https://gitlab.com/AOMediaCodec/SVT-AV1.git"
SVT_AV1_SOURCE_DIR = Path("svtav1_src").absolute()
SVT_AV1_INSTALL_DIR_NAME = "svtav1"
SVT_AV1_BUILD_DIR = SVT_AV1_SOURCE_DIR / "build"
SVT_AV1_GIT_OPTIONS: dict[str, Any] = {"--branch": "v2.3.0"}

VPX_REPO = "https://chromium.googlesource.com/webm/libvpx"
VPX_SOURCE_DIR = Path("vpx_src").absolute()
VPX_INSTALL_DIR_NAME = "vpx"
VPX_GIT_OPTIONS: dict[str, Any] = {}

OPUS_REPO = "https://gitlab.xiph.org/xiph/opus.git"
OPUS_SOURCE_DIR = Path("opus_src").absolute()
OPUS_INSTALL_DIR_NAME = "opus"
OPUS_GIT_OPTIONS: dict[str, Any] = {}

OGG_REPO = "https://gitlab.xiph.org/xiph/ogg.git"
OGG_SOURCE_DIR = Path("ogg_src").absolute()
OGG_INSTALL_DIR_NAME = "ogg"
OGG_GIT_OPTIONS: dict[str, Any] = {"--branch": "v1.3.5"}

VORBIS_REPO = "https://gitlab.xiph.org/xiph/vorbis.git"
VORBIS_SOURCE_DIR = Path("vorbis_src").absolute()
VORBIS_INSTALL_DIR_NAME = "vorbis"
VORBIS_GIT_OPTIONS: dict[str, Any] = {"--branch": "v1.3.7"}

MP3LAME_REPO = "https://svn.code.sf.net/p/lame/svn/trunk/lame"
MP3LAME_SOURCE_DIR = Path("mp3lame_src").absolute()
MP3LAME_INSTALL_DIR_NAME = "mp3lame"
MP3LAME_GIT_OPTIONS: dict[str, Any] = {"svn": True, "-r": "6525"}
