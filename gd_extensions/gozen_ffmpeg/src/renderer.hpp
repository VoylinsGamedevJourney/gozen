#pragma once
// This is the renderer, create an instance, feed it data, and make the finished video into a file.

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include "ffmpeg_includes.hpp"
#include "render_profile.hpp"


using namespace godot;

class GoZenRenderer : public Resource {
	GDCLASS(GoZenRenderer, Resource);

	private:
		struct SwsContext *p_sws_ctx;
		AVCodecContext *p_codec_context = NULL;
		const AVCodec *codec;
		FILE *p_output_file;
		AVPacket *p_packet;
		AVFrame *p_frame;
		int i, x, y;
		int byte_per_pixel = 3;


		void _encode(AVCodecContext *dec_ctx, AVFrame *frame, AVPacket *pkt, FILE *filename);
	

	public:
		Ref<GoZenRenderProfile> profile;


		GoZenRenderer() {}
		~GoZenRenderer();

		int open_ffmpeg(Ref<GoZenRenderProfile> new_profile);
		void send_frame(Ref<Image> frame_image);
		int close_ffmpeg();
	
	protected:
		static inline void _bind_methods() {	 
			ClassDB::bind_method(D_METHOD("open_ffmpeg", "new_profile:GoZenRenderProfile"), &GoZenRenderer::open_ffmpeg);
			ClassDB::bind_method(D_METHOD("send_frame", "frame_image"), &GoZenRenderer::send_frame);
			ClassDB::bind_method(D_METHOD("close_ffmpeg"), &GoZenRenderer::close_ffmpeg);
		}
};
