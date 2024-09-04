#pragma once


extern "C" {
	#include <libavcodec/avcodec.h>
	#include <libavcodec/codec.h>
	#include <libavcodec/codec_id.h>
	#include <libavcodec/packet.h>
	
	#include <libavdevice/avdevice.h>
	
	#include <libavformat/avformat.h>
	
	#include <libavutil/avassert.h>
	#include <libavutil/avutil.h>
	#include <libavutil/channel_layout.h>
	#include <libavutil/dict.h>
	#include <libavutil/error.h>
	#include <libavutil/frame.h>
	#include <libavutil/hwcontext.h>
	#include <libavutil/imgutils.h>
	#include <libavutil/mathematics.h>
	#include <libavutil/opt.h>
	#include <libavutil/pixdesc.h>
	#include <libavutil/rational.h>
	#include <libavutil/timestamp.h>
	
	#include <libswresample/swresample.h>
	#include <libswscale/swscale.h>
}
