#pragma once

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_wav.hpp>

#include <godot_cpp/variant/builtin_types.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "ffmpeg_includes.hpp"

using namespace godot;

class GoZenVideo : public Resource {
	GDCLASS(GoZenVideo, Resource);

	private:
		AVFormatContext *p_format_context = NULL;
		AVCodecContext *p_video_codec_context = NULL, *p_audio_codec_context;
		int width, height;
		struct SwsContext *p_sws_ctx = nullptr;
		struct SwrContext *p_swr_ctx = nullptr;
		enum AVPixelFormat pixel_format;
		AVStream *p_video_stream = NULL, *p_audio_stream = NULL;
		uint8_t *p_video_dst_data[4] = {NULL};
		int video_dst_linesize[4], video_dst_bufsize;
		int video_stream_index = -1, audio_stream_index = -1;
		AVFrame *p_frame = NULL;
		AVPacket *p_packet = NULL;
		PackedByteArray audio = PackedByteArray();
		Array video = Array();
		PackedByteArray subtitles = PackedByteArray();

		int swr_result;
		AVSampleFormat new_audio_format = AV_SAMPLE_FMT_S16; //AV_SAMPLE_FMT_FLT;//AVSampleFormat::AV_SAMPLE_FMT_S16 ;


		int open_codec_context(int *stream_index, AVCodecContext **codec_context, enum AVMediaType type);
		int decode_packet(AVCodecContext *codec, const AVPacket *packet);

		int output_video_frame(AVFrame *frame);
		int output_audio_frame(AVFrame *frame);

		void print_av_err(int errnum);

	public:
		GoZenVideo() {}
		~GoZenVideo() {}

		Dictionary get_container_data(String filename);


	protected:
		static void _bind_methods() {
			ClassDB::bind_method(D_METHOD("get_container_data", "filename:String"), &GoZenVideo::get_container_data);
		}
};