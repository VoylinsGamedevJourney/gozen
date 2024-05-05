#pragma once

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_wav.hpp>

#include <godot_cpp/variant/builtin_types.hpp>
#include <godot_cpp/variant/variant.hpp>
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

using namespace godot;

class Video : public Resource {
	GDCLASS(Video, Resource);

private:

	// Variables
	AVFormatContext* av_format_ctx = nullptr;
	AVStream* av_stream = nullptr;
	AVCodecContext* av_codec_ctx = nullptr;
	struct SwsContext* sws_ctx = nullptr;

	AVFrame* av_frame = nullptr;
	AVPacket* av_packet = nullptr;

	PackedByteArray byte_array = PackedByteArray();
	Ref<AudioStreamWAV> audio_stream_wav = memnew(AudioStreamWAV);

	int response = 0, src_linesize[4] = {0,0,0,0}, total_frame_number = 0;

	long start_time_video = 0, start_time_audio = 0, frame_timestamp = 0, current_pts = 0;
	double average_frame_duration = 0, stream_time_base_video = 0, stream_time_base_audio = 0;

public:

	Video() {}
	~Video() { close(); }


	void open(String a_path);
	void close();

	Ref<Image> seek_frame(int a_frame_nr);
	Ref<Image> next_frame();

	inline Ref<AudioStreamWAV> get_audio() { return audio_stream_wav; }

	inline int get_total_frame_nr() const { return total_frame_number;};
	void _get_total_frame_nr();

	Vector2i get_size() const { return Vector2i(av_codec_ctx->width, av_codec_ctx->height); }

	void printerr(String a_message);
	void print_av_error(String a_message);

	static Dictionary get_video_file_meta(String a_file_path);


protected:

	bool is_open = false;


	static void _bind_methods();
	
};