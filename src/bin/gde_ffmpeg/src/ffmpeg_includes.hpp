#pragma once

extern "C" {
  #include <libavcodec/avcodec.h>
  #include <libavformat/avformat.h>
  #include <libavdevice/avdevice.h>
  #include <libavfilter/avfilter.h>
  #include <libavutil/dict.h>
  #include <libpostproc/postprocess.h>
  #include <libavutil/channel_layout.h>
  #include <libavutil/opt.h>
  #include <libavutil/imgutils.h>
  #include <libavutil/pixdesc.h>
  #include <libswscale/swscale.h>
  #include <libswresample/swresample.h>
}