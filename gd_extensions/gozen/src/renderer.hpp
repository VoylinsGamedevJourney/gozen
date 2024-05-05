#pragma once

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

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

#include "render_profile.hpp"


using namespace godot;


class Renderer : public Resource {
	GDCLASS(Renderer, Resource);


private:

	struct SwsContext *sws_ctx;
	AVCodecContext *av_codec_ctx = NULL;
	AVPacket *av_packet;
	AVFrame *av_frame;

	FILE *output_file;

	int i = 0, x = 0, y = 0, byte_per_pixel = 3; // Byte per pixel should be 4 for alpha!


	void _encode(AVCodecContext *dec_ctx, AVFrame *frame, AVPacket *pkt, FILE *filename);
	

public:
	
	Ref<RenderProfile> profile = nullptr;

	~Renderer() { close(); }

	void open(Ref<RenderProfile> a_profile);
	void send_frame(Ref<Image> a_frame_image);
	void close();

	static bool is_codec_supported(RenderProfile::CODEC a_codec);
	static Array get_supported_video_codecs();
	static Array get_supported_audio_codecs();
	

protected:

	bool is_open = false;

	static void _bind_methods();
};
