#include "video_meta.hpp"


bool VideoMeta::load_meta(const String &video_path) {
	meta_loaded = false;
	path = video_path;

	UniqueAVFormatContextInput av_format_ctx;
	UniqueAVCodecContext av_codec_ctx_video;
	UniqueAVFrame av_frame;
	UniqueAVPacket av_packet;

	// Opening file.
	AVFormatContext* temp_format_ctx = nullptr;
	if (avformat_open_input(&temp_format_ctx, path.utf8().get_data(),
						 nullptr, nullptr) != 0)
		return _log_err("Couldn't open video file: " + path);

	av_format_ctx = make_unique_ffmpeg<
			AVFormatContext, AVFormatContextInputDeleter>(temp_format_ctx);

	if (avformat_find_stream_info(av_format_ctx.get(), nullptr) < 0)
		return _log_err("Couldn't find stream information in: " + path);

	// Find video stream.
	AVStream* stream_video = nullptr;
	int stream_index = -1;

	for (unsigned int i = 0; i < av_format_ctx->nb_streams; i++) {
		AVStream* current_stream = av_format_ctx->streams[i];

		if (current_stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
			if (avcodec_find_decoder(current_stream->codecpar->codec_id)) {
				stream_video = current_stream;
				stream_index = i;
				break;
			}
		}
	}

	if (!stream_video)
		return _log_err(
			"No decodable video stream found for metadata extraction in: " +
			path);

	// Get basic stream info.
	resolution.x = stream_video->codecpar->width;
	resolution.y = stream_video->codecpar->height;
	framerate = av_q2d(av_guess_frame_rate(
			av_format_ctx.get(), stream_video, nullptr));

	if (framerate <= 0)
		framerate = av_q2d(stream_video->avg_frame_rate);
	if (framerate <= 0)
		framerate = av_q2d(stream_video->r_frame_rate);
	if (framerate <= 0) {
		_log("Could not determine framerate reliably");
		framerate = 0.0f;
	}

	// Figuring out duration.
	if (stream_video->duration != AV_NOPTS_VALUE)
		duration_us = av_rescale_q(stream_video->duration,
								   stream_video->time_base, AV_TIME_BASE_Q);
	else if (av_format_ctx->duration != AV_NOPTS_VALUE)
		duration_us = av_format_ctx->duration;
	else {
		duration_us = 0;
		_log("Could not determine video duration");
	}

	if (framerate > 0 && duration_us > 0)
		frame_count = static_cast<int64_t>(
				round(get_duration_seconds() * framerate));
	else
		frame_count = 0;

	pixel_format_name = av_get_pix_fmt_name(
			static_cast<AVPixelFormat>(stream_video->codecpar->format));
	color_primaries_name =
			av_color_primaries_name(stream_video->codecpar->color_primaries);
	color_trc_name = av_color_transfer_name(
			stream_video->codecpar->color_trc);
	color_space_name = av_color_space_name(
			stream_video->codecpar->color_space);
	is_full_color_range = 
			stream_video->codecpar->color_range == AVCOL_RANGE_JPEG;

	// Getting rotation.
	// Modern method has deprecated stuff issues, so we just check video meta.
	rotation = 0;
	AVDictionaryEntry* rotate_tag = av_dict_get(
			stream_video->metadata, "rotate", nullptr, 0);

	if (rotate_tag && rotate_tag->value) {
		rotation = atoi(rotate_tag->value);

		if (rotation == -90)
			rotation = 270;

		rotation = rotation % 360;
		if (rotation < 0)
			rotation += 360;

		if (rotation != 0 && rotation != 90 && rotation != 180 &&
			rotation != 270) {
			_log("Non-standard rotation metadata tag found: " +
					String::num_int64(rotation) + ". Resetting to 0");
			rotation = 0;
		}
	}

	is_interlaced = false;

	const AVCodec* codec_video = avcodec_find_decoder(
			stream_video->codecpar->codec_id);

	if (codec_video) {
		av_codec_ctx_video = make_unique_ffmpeg<
				AVCodecContext, AVCodecContextDeleter>(
				avcodec_alloc_context3(codec_video));

		if (av_codec_ctx_video && avcodec_parameters_to_context(
					av_codec_ctx_video.get(), stream_video->codecpar) >= 0) {
			if (avcodec_open2(av_codec_ctx_video.get(), codec_video, nullptr)
					>= 0) {
				av_frame = make_unique_avframe();
				av_packet = make_unique_avpacket();
				if (av_frame && av_packet) {
					av_seek_frame(av_format_ctx.get(), stream_index,
							stream_video->start_time != AV_NOPTS_VALUE
							? stream_video->start_time : 0,
							AVSEEK_FLAG_BACKWARD);

					avcodec_flush_buffers(av_codec_ctx_video.get());
					bool eof = false;

					if (FFmpeg::get_frame(
							av_format_ctx.get(), av_codec_ctx_video.get(),
							stream_index, av_frame.get(), av_packet.get())) {
						_log_err("Something went wrong getting frame data!");
						return false;
					}

					is_interlaced = (
							av_codec_ctx_video->field_order != AV_FIELD_PROGRESSIVE
							&& av_codec_ctx_video->field_order != AV_FIELD_UNKNOWN);

					padding = av_frame->linesize[0] - resolution.x;
					av_frame_unref(av_frame.get());
				}
			}
		}
	}

	meta_loaded = true;
	return true;
}

#define BIND_METHOD(a_method_name) \
ClassDB::bind_method(D_METHOD(#a_method_name), &VideoMeta::a_method_name)

#define BIND_METHOD_1(a_method_name, a_param1) \
ClassDB::bind_method(D_METHOD(#a_method_name, a_param1), \
							  &VideoMeta::a_method_name)

void VideoMeta::_bind_methods() {
	BIND_METHOD_1(load_meta, "video_path");
	BIND_METHOD(is_loaded);

	BIND_METHOD(get_path);

	BIND_METHOD(get_resolution);
	BIND_METHOD(get_width);
	BIND_METHOD(get_height);

	BIND_METHOD(get_framerate);
	BIND_METHOD(get_frame_count);
	BIND_METHOD(get_duration_microseconds);
	BIND_METHOD(get_duration_seconds);
	BIND_METHOD(get_rotation);
	BIND_METHOD(get_padding);

	BIND_METHOD(get_pixel_format_name);
	BIND_METHOD(get_color_primaries_name);
	BIND_METHOD(get_color_trc_name);
	BIND_METHOD(get_color_space_name);

	BIND_METHOD(get_is_full_color_range);
	BIND_METHOD(get_is_interlaced);
}

