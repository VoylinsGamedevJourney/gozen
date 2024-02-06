#include "gozen_renderer.hpp"


GoZenRenderer::~GoZenRenderer() {
  if (p_codec_context)
    close_ffmpeg();
}


int GoZenRenderer::open_ffmpeg(Ref<GoZenRenderProfile> new_profile) {
  // Check to see if render profile is complete
  if (!new_profile->check()) {
    UtilityFunctions::printerr("Render profile not ready!");
    return -1;
  }
  profile = new_profile;
  if (profile->get_alpha_layer()) {
    byte_per_pixel = 4;
  }
 
  // Find encoder
  codec = avcodec_find_encoder(profile->video_codec);
  if (!codec) {
    UtilityFunctions::printerr("Codec not found!");
    return -1;
  }
 
  p_codec_context = avcodec_alloc_context3(codec);
  if (!p_codec_context) {
    UtilityFunctions::printerr("Could not allocate video codec context!");
    return -1;
  }
 
  p_packet = av_packet_alloc();
  if (!p_packet) {
    UtilityFunctions::printerr("Could not allocate packet!");
    return -1;
  }
 
  p_codec_context->bit_rate = profile->bit_rate;
  p_codec_context->pix_fmt = AV_PIX_FMT_YUV420P;
  p_codec_context->width = profile->video_size.x;
  p_codec_context->height = profile->video_size.y;
  p_codec_context->time_base.num = 1;
  p_codec_context->time_base.den = profile->framerate;
  p_codec_context->framerate.num = profile->framerate;
  p_codec_context->framerate.den = 1;
  p_codec_context->gop_size = 10;
  p_codec_context->max_b_frames = 1;
 
  // TODO: Add options in render profile for these type of things
  //if (codec->id == AV_CODEC_ID_H264)
  //  av_opt_set(p_codec_context->priv_data, "preset", "slow", 0);
 
  // Open video file
  if (avcodec_open2(p_codec_context, codec, NULL) < 0) {
    UtilityFunctions::printerr("Could not open codec!"); 
    return -1;
  }
 
  // Opening video file
  p_output_file = fopen(profile->filename.utf8(), "wb");
  if (!p_output_file) {
    UtilityFunctions::printerr("Could not open video file!");
    return -1;
  }
 
  p_frame = av_frame_alloc();
  if (!p_frame) {
    UtilityFunctions::printerr("Could not allocate video frame!");
    return -1;
  }
  p_frame->format = p_codec_context->pix_fmt;
  p_frame->width  = p_codec_context->width;
  p_frame->height = p_codec_context->height;
 
  if (av_frame_get_buffer(p_frame, 0) < 0) {
    UtilityFunctions::printerr("Could not allocate the video frame data!");
    return -1;
  }

  p_sws_ctx = sws_getContext(
      p_frame->width, p_frame->height, AV_PIX_FMT_RGB24, // AV_PIX_FMT_RGBA was it before
      p_frame->width, p_frame->height, AV_PIX_FMT_YUV420P,
      SWS_BILINEAR, NULL, NULL, NULL); // TODO: Option to change: SWS_BILINEAR in profile (low quality has trouble with this)
  if (!p_sws_ctx) {
    UtilityFunctions::printerr("Could not get sws context!");
    return -1;
  }

  i = 0; // Reset i for send_frame()
  return 0;
}


// TODO: Make argument int frame_nr, this could allow for multi-threaded rendering ... maybe
void GoZenRenderer::send_frame(Ref<Image> frame_image) {
  if (!p_codec_context) {
    UtilityFunctions::printerr("No ffmpeg instance running!");
    return;
  }

  // Making sure frame is write-able
  if (av_frame_make_writable(p_frame) < 0)
    return;

  uint8_t *src_data[4] = { frame_image->get_data().ptrw(), NULL, NULL, NULL };
  int src_linesize[4] = { p_frame->width * byte_per_pixel, 0, 0, 0 };
  sws_scale(p_sws_ctx, src_data, src_linesize, 0, p_frame->height, p_frame->data, p_frame->linesize);

  p_frame->pts = i;
  i++;
  _encode(p_codec_context, p_frame, p_packet, p_output_file);
}


int GoZenRenderer::close_ffmpeg() {
  if (!p_codec_context) {
    UtilityFunctions::printerr("No ffmpeg instance running!");
    return -1;
  }

  const uint8_t endcode[] = { 0, 0, 1, 0xb7 };

  // Flush encoder 
  _encode(p_codec_context, NULL, p_packet, p_output_file);
 
  // Add sequence end code to complete file data
  // Does not work for all codecs (some require packets)
  if (codec->id == AV_CODEC_ID_MPEG1VIDEO || codec->id == AV_CODEC_ID_MPEG2VIDEO)
    fwrite(endcode, 1, sizeof(endcode), p_output_file);
  fclose(p_output_file);
 
  avcodec_free_context(&p_codec_context);
  av_frame_free(&p_frame);
  av_packet_free(&p_packet);
  sws_freeContext(p_sws_ctx);
 
  return 0;
}


void GoZenRenderer::_encode(AVCodecContext *p_codec_context, AVFrame *p_frame, AVPacket *p_packet, FILE *p_output_file) {
  // Send frame to the encoder
  int ret = avcodec_send_frame(p_codec_context, p_frame);
  if (ret < 0) {
    UtilityFunctions::printerr("Error sending a frame for encoding!");
    return;
  }

  while (ret >= 0) {
    ret = avcodec_receive_packet(p_codec_context, p_packet);
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
      return;
    else if (ret < 0) {
      UtilityFunctions::printerr(stderr, "Error during encoding!");
      return;
    }
    fwrite(p_packet->data, 1, p_packet->size, p_output_file);
    av_packet_unref(p_packet);
  }
}
