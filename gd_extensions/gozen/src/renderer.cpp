#include "renderer.hpp"



void Renderer::open(Ref<RenderProfile> a_profile) {
	// Check to see if render profile is complete
	if (!a_profile->check()) {
		UtilityFunctions::printerr("Render profile not ready!");
		return;
	}
	profile = a_profile;
	if (profile->get_alpha_layer()) {
		byte_per_pixel = 4;
	}
 
	// Find encoder
	const AVCodec *av_codec = avcodec_find_encoder(profile->video_codec);
	if (!av_codec) {
		UtilityFunctions::printerr("Couldn't find codec!");
		return;
	}
 
	av_codec_ctx = avcodec_alloc_context3(av_codec);
	if (!av_codec_ctx) {
		UtilityFunctions::printerr("Couldn't allocate video codec context!");
		return;
	}
 
	av_packet = av_packet_alloc();
	if (!av_packet) {
		UtilityFunctions::printerr("Could not allocate packet!");
		return;
	}
 
	av_codec_ctx->bit_rate = profile->bit_rate;
	av_codec_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
	av_codec_ctx->width = profile->video_size.x;
	av_codec_ctx->height = profile->video_size.y;
	av_codec_ctx->time_base.num = 1;
	av_codec_ctx->time_base.den = profile->framerate;
	av_codec_ctx->framerate.num = profile->framerate;
	av_codec_ctx->framerate.den = 1;
	av_codec_ctx->gop_size = 10;
	av_codec_ctx->max_b_frames = 1;
 
	// TODO: Add options in render profile for these type of things
	//if (codec->id == AV_CODEC_ID_H264)
	//	av_opt_set(av_codec_ctx->priv_data, "preset", "slow", 0);
 
	// Open video file
	if (avcodec_open2(av_codec_ctx, av_codec, NULL) < 0) {
		UtilityFunctions::printerr("Could not open codec!"); 
		return;
	}
 
	// Opening video file
	output_file = fopen(profile->filename.utf8(), "wb");
	if (!output_file) {
		UtilityFunctions::printerr("Could not open video file!");
		return;
	}
 
	av_frame = av_frame_alloc();
	if (!av_frame) {
		UtilityFunctions::printerr("Could not allocate video frame!");
		return;
	}
	av_frame->format = av_codec_ctx->pix_fmt;
	av_frame->width	= av_codec_ctx->width;
	av_frame->height = av_codec_ctx->height;
 
	if (av_frame_get_buffer(av_frame, 0) < 0) {
		UtilityFunctions::printerr("Could not allocate the video frame data!");
		return;
	}

	sws_ctx = sws_getContext(
			av_frame->width, av_frame->height, AV_PIX_FMT_RGB24, // AV_PIX_FMT_RGBA was it before
			av_frame->width, av_frame->height, AV_PIX_FMT_YUV420P,
			SWS_BILINEAR, NULL, NULL, NULL); // TODO: Option to change: SWS_BILINEAR in profile (low quality has trouble with this)
	if (!sws_ctx) {
		UtilityFunctions::printerr("Could not get sws context!");
		return;
	}

	i = 0; // Reset i for send_frame()
	is_open = true;
}


// TODO: Make argument int frame_nr, this could allow for multi-threaded rendering ... maybe
void Renderer::send_frame(Ref<Image> a_frame_image) {
	if (!av_codec_ctx) {
		UtilityFunctions::printerr("No ffmpeg instance running!");
		return;
	}

	// Making sure frame is write-able
	if (av_frame_make_writable(av_frame) < 0)
		return;

	uint8_t *src_data[4] = { a_frame_image->get_data().ptrw(), NULL, NULL, NULL };
	int src_linesize[4] = { av_frame->width * byte_per_pixel, 0, 0, 0 };
	sws_scale(sws_ctx, src_data, src_linesize, 0, av_frame->height, av_frame->data, av_frame->linesize);

	av_frame->pts = i;
	i++;
	_encode(av_codec_ctx, av_frame, av_packet, output_file);
}


void Renderer::close() {

	if (!is_open) {
		UtilityFunctions::printerr("Renderer isn't open!");
		return;
	}
	if (!av_codec_ctx) {
		UtilityFunctions::printerr("No ffmpeg instance running!");
		return;
	}

	const uint8_t endcode[] = { 0, 0, 1, 0xb7 };

	// Flush encoder 
	_encode(av_codec_ctx, NULL, av_packet, output_file);
 
	// Add sequence end code to complete file data
	// Does not work for all codecs (some require packets)
	if (av_codec_ctx->codec_id == AV_CODEC_ID_MPEG1VIDEO || av_codec_ctx->codec_id == AV_CODEC_ID_MPEG2VIDEO)
		fwrite(endcode, 1, sizeof(endcode), output_file);
	fclose(output_file);
 
	avcodec_free_context(&av_codec_ctx);
	av_frame_free(&av_frame);
	av_packet_free(&av_packet);
	sws_freeContext(sws_ctx);
}


void Renderer::_encode(AVCodecContext *a_codec_context, AVFrame *a_frame, AVPacket *a_packet, FILE *a_output_file) {
	// Send frame to the encoder
	int ret = avcodec_send_frame(a_codec_context, av_frame);
	if (ret < 0) {
		UtilityFunctions::printerr("Error sending a frame for encoding!");
		return;
	}

	while (ret >= 0) {
		ret = avcodec_receive_packet(a_codec_context, av_packet);
		if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
			return;
		else if (ret < 0) {
			UtilityFunctions::printerr(stderr, "Error during encoding!");
			return;
		}
		fwrite(av_packet->data, 1, av_packet->size, output_file);
		av_packet_unref(av_packet);
	}
}


bool Renderer::is_codec_supported(RenderProfile::CODEC codec) { 
	return ((const AVCodec*)avcodec_find_encoder(static_cast<AVCodecID>(codec)));
}


Array Renderer::get_supported_video_codecs() {
	Array codecs = Array();
	std::pair<RenderProfile::CODEC, String> video_codecs[] = {
		{RenderProfile::H264, "H264"},
		{RenderProfile::H265, "H265"},
		{RenderProfile::MPEG1, "MPEG1"},
		{RenderProfile::MPEG2, "MPEG2"},
		{RenderProfile::MPEG4, "MPEG4"},
		{RenderProfile::VP8, "VP8"},
		{RenderProfile::VP9, "VP9"},
		{RenderProfile::AV1, "AV1"},
	};

	for (const auto& v_codec : video_codecs) {
		const AVCodec* codec = avcodec_find_encoder(static_cast<AVCodecID>(v_codec.first));
		Dictionary entry = {};
		entry["codec_id"] = v_codec.second;
		entry["supported"] = is_codec_supported(v_codec.first);
		entry["hardware_accel"] = codec->capabilities & AV_CODEC_CAP_HARDWARE;
		codecs.append(entry);
	}

	return codecs;
}


Array Renderer::get_supported_audio_codecs() {
	Array codecs = Array();
	std::pair<RenderProfile::CODEC, String> audio_codecs[] = {
		{RenderProfile::MP3, "MP3"},
		{RenderProfile::AAC, "AAC"},
		{RenderProfile::OPUS, "OPUS"},
		{RenderProfile::VORBIS, "VORBIS"},
		{RenderProfile::FLAC, "FLAC"},
		{RenderProfile::AC3, "AC3"},
		{RenderProfile::EAC3, "EAC3"},
		{RenderProfile::WAV, "WAV"},
	};

	for (const auto& a_codec : audio_codecs) {
		const AVCodec* codec = avcodec_find_encoder(static_cast<AVCodecID>(a_codec.first));
		Dictionary entry = {};
		entry["codec_id"] = a_codec.second;
		entry["supported"] = is_codec_supported(a_codec.first);
		entry["hardware_accel"] = codec->capabilities & AV_CODEC_CAP_HARDWARE;
		codecs.append(entry);
	}

	return codecs;
}


void Renderer::_bind_methods() {
	ClassDB::bind_method(D_METHOD("open", "new_profile:RenderProfile"), &Renderer::open);
	ClassDB::bind_method(D_METHOD("close"), &Renderer::close);

	ClassDB::bind_method(D_METHOD("send_frame", "frame_image"), &Renderer::send_frame);

	ClassDB::bind_static_method("Renderer", D_METHOD("get_supported_video_codecs"), &Renderer::get_supported_video_codecs);
	ClassDB::bind_static_method("Renderer", D_METHOD("get_supported_audio_codecs"), &Renderer::get_supported_audio_codecs);
	ClassDB::bind_static_method("Renderer", D_METHOD("is_codec_supported", "codec:CODEC"), &Renderer::is_codec_supported);
}
