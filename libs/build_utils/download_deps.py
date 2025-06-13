#!/usr/bin/env python3

import os
from pathlib import Path
from typing import Optional

from .consts import (
    AOM_BUILD_DIR,
    AOM_REPO,
    AOM_SOURCE_DIR,
    MP3LAME_GIT_OPTIONS,
    MP3LAME_REPO,
    MP3LAME_SOURCE_DIR,
    OGG_GIT_OPTIONS,
    OGG_REPO,
    OGG_SOURCE_DIR,
    OPUS_REPO,
    OPUS_SOURCE_DIR,
    SVT_AV1_BUILD_DIR,
    SVT_AV1_GIT_OPTIONS,
    SVT_AV1_REPO,
    SVT_AV1_SOURCE_DIR,
    VORBIS_GIT_OPTIONS,
    VORBIS_REPO,
    VORBIS_SOURCE_DIR,
    VPX_REPO,
    VPX_SOURCE_DIR,
    X264_REPO,
    X264_SOURCE_DIR,
    X265_BUILD_DIR,
    X265_REPO,
    X265_SOURCE_DIR,
)
from .utils import GIT_PATH, run_command


def clone_dep(
    repo: str,
    source_dir: Path,
    build_dir: Optional[Path] = None,
    svn: bool = False,
    **kwargs,
) -> None:
    if os.path.exists(source_dir):
        return

    print(f"Downloading {repo} to {source_dir}...")
    build_dir = build_dir or source_dir

    if svn:
        cmd = [GIT_PATH, "svn", "clone", repo, str(source_dir), "--revision", "HEAD"]
    else:
        cmd = [
            GIT_PATH,
            "clone",
            repo,
            str(source_dir),
        ]

    cmd += [arg for (k, v) in kwargs.items() for arg in (k, v)]
    run_command(cmd, cwd="./", check=True)


def download_ffmpeg_deps() -> None:
    clone_dep(X264_REPO, X264_SOURCE_DIR)
    clone_dep(X265_REPO, X265_SOURCE_DIR, build_dir=X265_BUILD_DIR)
    clone_dep(AOM_REPO, AOM_SOURCE_DIR, build_dir=AOM_BUILD_DIR)
    clone_dep(
        SVT_AV1_REPO,
        SVT_AV1_SOURCE_DIR,
        build_dir=SVT_AV1_BUILD_DIR,
        svn=False,
        **SVT_AV1_GIT_OPTIONS,
    )
    clone_dep(VPX_REPO, VPX_SOURCE_DIR)
    clone_dep(OPUS_REPO, OPUS_SOURCE_DIR)
    clone_dep(OGG_REPO, OGG_SOURCE_DIR, build_dir=None, **OGG_GIT_OPTIONS)
    clone_dep(VORBIS_REPO, VORBIS_SOURCE_DIR, build_dir=None, **VORBIS_GIT_OPTIONS)
    clone_dep(
        MP3LAME_REPO,
        MP3LAME_SOURCE_DIR,
        build_dir=None,
        **MP3LAME_GIT_OPTIONS,
    )


if __name__ == "__main__":
    download_ffmpeg_deps()
