#include "gozen_importer.hpp"


Dictionary GoZenImporter::get_container_data(String filename) {
  int ret = 0;
  Dictionary data = {};

  // Open file + allocate format context
  if (avformat_open_input(&p_format_context, filename.utf8(), NULL, NULL) < 0) {
    UtilityFunctions::printerr("Could not open file!");
    return data;
  }

  // Get stream info
  if (avformat_find_stream_info(p_format_context, NULL) < 0) {
    UtilityFunctions::printerr("Could not get stream info!");
    return data;
  }

  if (open_codec_context(&video_stream_index, &p_video_codec_context, AVMEDIA_TYPE_VIDEO) >= 0) {
    p_video_stream = p_format_context->streams[video_stream_index];

    // Allocate the image where the decoded image will be put
    width = p_video_codec_context->width;
    height = p_video_codec_context->height;
    pixel_format = p_video_codec_context->pix_fmt;
    ret = av_image_alloc(p_video_dst_data, video_dst_linesize, width, height, pixel_format, 1);
    if (ret < 0) {
      UtilityFunctions::printerr("Could not allocate raw video buffer!");
      goto end;
    }

    video_dst_bufsize = ret;
  }

  if (open_codec_context(&audio_stream_index, &p_audio_codec_context, AVMEDIA_TYPE_AUDIO) >= 0) {
    p_audio_stream = p_format_context->streams[audio_stream_index];
  }

  // Dumping info to stderr
  av_dump_format(p_format_context, 0, filename.utf8(), 0);

  if (!p_video_stream && !p_audio_stream) {
    UtilityFunctions::printerr("Could not find audio or video stream in input!");
    goto end;
  }

  p_frame = av_frame_alloc();
  if (!p_frame) {
    UtilityFunctions::printerr("Could not allocate frame!");
    goto end;
  }

  p_packet = av_packet_alloc();
  if (!p_packet) {
    UtilityFunctions::printerr("Could not allocate packet!");
    goto end;
  }
  
  p_sws_ctx = sws_getContext(
      width, height, AV_PIX_FMT_YUV420P,
      width, height, AV_PIX_FMT_RGB24,
      SWS_BILINEAR, NULL, NULL, NULL); // TODO: Option to change: SWS_BILINEAR in profile (low quality has trouble with this)
  if (!p_sws_ctx) {
    UtilityFunctions::printerr("Could not get sws context!");
    goto end;
  } else {
    UtilityFunctions::print("Allocated SWS");
  }

  
  swr_result = swr_alloc_set_opts2(
		&p_swr_ctx,
		&p_audio_codec_context->ch_layout, new_audio_format, p_audio_codec_context->sample_rate,
		&p_audio_codec_context->ch_layout, p_audio_codec_context->sample_fmt, p_audio_codec_context->sample_rate,
		0, nullptr);
	if (swr_result < 0) {
		UtilityFunctions::printerr("Failed to obtain SWR context");
    print_av_err(swr_result);
		goto end;
	}
  if (!p_swr_ctx || swr_init(p_swr_ctx) < 0) {
    UtilityFunctions::print("Could not allocate resampler context!");
    goto end;
  } else {
    UtilityFunctions::print("Allocated SWR");
  }

  if (p_video_stream) UtilityFunctions::print("Demuxing video from file.");
  if (p_audio_stream) UtilityFunctions::print("Demuxing audio from file.");
  
  // Reading frames from file
  while (av_read_frame(p_format_context, p_packet) >= 0) {
    // Check if packet belongs to a stream we need, else skip
    if (p_packet->stream_index == video_stream_index)
      ret = decode_packet(p_video_codec_context, p_packet);
    else if (p_packet->stream_index == audio_stream_index)
      ret = decode_packet(p_audio_codec_context, p_packet);
    av_packet_unref(p_packet);
    if (ret < 0) break;
  }

  // Flush decoders
  if (p_video_codec_context)
    decode_packet(p_video_codec_context, NULL);
  if (p_audio_codec_context)
    decode_packet(p_audio_codec_context, NULL);
  
  UtilityFunctions::print("Demuxing complete!");
  data["video"] = video;
  data["audio"] = audio;
  data["subtitles"] = subtitles;

end:
  avcodec_free_context(&p_video_codec_context);
  avcodec_free_context(&p_audio_codec_context);
  avformat_close_input(&p_format_context);
  
  av_packet_free(&p_packet);
  av_frame_free(&p_frame);
  av_free(p_video_dst_data[0]);

  sws_freeContext(p_sws_ctx);
  swr_free(&p_swr_ctx);

  return data;
}


int GoZenImporter::open_codec_context(int *stream_index, AVCodecContext **codec_context, enum AVMediaType type) {
  int ret, stream_idx;
  AVStream *p_stream;
  const AVCodec *codec = NULL;

  ret = av_find_best_stream(p_format_context, type, -1, -1, NULL, 0);
  if (ret < 0) {
    UtilityFunctions::printerr("Could not find stream of type '" + static_cast<String>(av_get_media_type_string(type)) +  "'!");
  } else {
    stream_idx = ret;
    p_stream = p_format_context->streams[stream_idx];

    // Find decoder for stream
    codec = avcodec_find_decoder(p_stream->codecpar->codec_id);
    if (!codec) {
      UtilityFunctions::printerr("Could not find decoder!");
      return AVERROR(EINVAL);
    }

    // Allocate codec context for decoder
    *codec_context = avcodec_alloc_context3(codec);
    if (!*codec_context) {
      UtilityFunctions::printerr("Failed to allocate the codec context!");
      return AVERROR(ENOMEM);
    }

    // Copy codec params from input stream to codec context output
    if ((ret = avcodec_parameters_to_context(*codec_context, p_stream->codecpar)) < 0) {
      UtilityFunctions::printerr("Failed to copy codec params to decoder context!");
      return ret;
    }

    // Initialize decoders
    if ((ret = avcodec_open2(*codec_context, codec, NULL) < 0)) {
      UtilityFunctions::printerr("Failed to init codec!");
      return ret;
    }
    *stream_index = stream_idx;
  }

  return 0;
}


int GoZenImporter::decode_packet(AVCodecContext *codec, const AVPacket *packet) {
  int ret = 0;

  // Submit packet to decoder
  ret = avcodec_send_packet(codec, packet);
  if (ret < 0) {
    UtilityFunctions::printerr("Error submitting a packet for decoding!");
    return ret;
  }

  // Get all available frames from decoder
  while (ret >= 0) {
    ret = avcodec_receive_frame(codec, p_frame);
    if (ret < 0) {
      // If return values equals these, then no output frame is available,
      // but there were also no errors.
      if (ret == AVERROR_EOF || ret == AVERROR(EAGAIN))
        return 0;
      
      UtilityFunctions::printerr("Error during decoding!");
      return ret;
    }

    // Write frame data to output file
    if (codec->codec->type == AVMEDIA_TYPE_VIDEO)
      ret = output_video_frame(p_frame);
    else if (codec->codec->type == AVMEDIA_TYPE_AUDIO)
      ret = output_audio_frame(p_frame);
    else
      // This will probably never print, but this is in preparation
      // for getting the subtitle stream data
      UtilityFunctions::printerr("Unknown type!");
    
    if (ret < 0)
      return ret;
  }

  return 0;
}


int GoZenImporter::output_video_frame(AVFrame *frame) {
  if (frame->width != width || frame->height != height || frame->format != pixel_format) {
    UtilityFunctions::printerr("Some change happened, width/height/pixel_format is not constant!");
    return -1;
  }

  // Copy decoded frame to destination buffer
  //av_image_copy(p_video_dst_data, video_dst_linesize,(const uint8_t **)(frame->data), frame->linesize, pixel_format, width, height);

  //
  // Here is where the writing to the raw video file happens
  //fwrite(p_video_dst_data[0], 1, video_dst_bufsize, video_destination_file);
  //

  PackedByteArray byte_array = PackedByteArray();
  const int expected_rgb_size = width * height * 3;
  int src_linesize[4] = { width * 3, 0, 0, 0 };
  byte_array.resize(expected_rgb_size);
  uint8_t *w = byte_array.ptrw();

  uint8_t *dest_data[1] = { w };
  sws_scale(p_sws_ctx, frame->data, frame->linesize, 0, frame->height, dest_data, src_linesize);

  Ref<Image> image = memnew(Image);
  // memcpy not possible as this would copy the yuv420p format
  //memcpy(dest_data, p_video_dst_data[0], expected_rgb_size);
  image->set_data(width, height, false, image->FORMAT_RGB8, byte_array);
  Ref<ImageTexture> tex = memnew(ImageTexture);
  tex->set_image(image);
  video.append(tex);

  return 0;
}


int GoZenImporter::output_audio_frame(AVFrame *frame) {
  AVFrame *new_frame;
  new_frame = av_frame_alloc();
	new_frame->format = new_audio_format;
	new_frame->ch_layout = p_audio_codec_context->ch_layout;
	new_frame->sample_rate = p_audio_codec_context->sample_rate;
	new_frame->nb_samples = frame->nb_samples; //swr_get_out_samples(p_swr_ctx, frame->nb_samples);

  int result = av_frame_get_buffer(new_frame, 0);
	if (result < 0) {
    UtilityFunctions::printerr("Could not allocate new frame for swr!");
    print_av_err(result);
		av_frame_unref(new_frame);
		return -1;
	}
  
  result = swr_convert_frame(p_swr_ctx, new_frame, frame);
	if (result < 0) {
		UtilityFunctions::printerr("Could not convert audio frame!");
    print_av_err(result);
		av_frame_unref(new_frame);
		return -1;
	}
  
  size_t unpadded_linesize = frame->nb_samples * av_get_bytes_per_sample(new_audio_format); 

  std::vector<int16_t> audio_vector(unpadded_linesize);
  memcpy(audio_vector.data(), new_frame->extended_data[0], unpadded_linesize);

  PackedByteArray byte_array = PackedByteArray();
  byte_array.resize(unpadded_linesize * 2);

  int64_t byte_offset = 0;
  for (size_t i = 0; i < unpadded_linesize; ++i) {
    int16_t value = ((int16_t*)new_frame->extended_data[0])[i];
    byte_array.encode_s16(byte_offset, value);
    byte_offset += sizeof(int16_t);
  }

  audio.append_array(byte_array);
  av_frame_unref(frame);
  return 0;
}


void GoZenImporter::print_av_err(int errnum) {
  char error_buffer[AV_ERROR_MAX_STRING_SIZE];
  av_strerror(errnum, error_buffer, sizeof(error_buffer));
  std::string av_err_str = "AV ERROR: " + std::to_string(errnum) + " - " + error_buffer;
  UtilityFunctions::printerr(av_err_str.c_str());
  std::cout << error_buffer << std::endl;
}
