#pragma once

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include "ffmpeg_includes.hpp"

using namespace godot;


class GoZenRenderProfile: public Resource {
  GDCLASS(GoZenRenderProfile, Resource);

  public:
    enum CODEC {
      /* Audio codecs */
      MP3 = AV_CODEC_ID_MP3,
      AAC = AV_CODEC_ID_AAC,
      OPUS = AV_CODEC_ID_OPUS,
      VORBIS = AV_CODEC_ID_VORBIS,
      FLAC = AV_CODEC_ID_FLAC,
      PCM_UNCOMPRESSED = AV_CODEC_ID_PCM_S16LE,
      AC3 = AV_CODEC_ID_AC3,
      EAC3 = AV_CODEC_ID_EAC3,
      WAV = AV_CODEC_ID_WAVPACK,
      /* Video codecs */
      H264 = AV_CODEC_ID_H264,
      H265 = AV_CODEC_ID_HEVC,
      VP9 = AV_CODEC_ID_VP9,
      MPEG4 = AV_CODEC_ID_MPEG4,
      MPEG2 = AV_CODEC_ID_MPEG2VIDEO,
      MPEG1 = AV_CODEC_ID_MPEG1VIDEO,
      AV1 = AV_CODEC_ID_AV1,
      VP8 = AV_CODEC_ID_VP8,
    };


    String filename;
    AVCodecID video_codec, audio_codec;
    Vector2i video_size;
    int framerate = -1, bit_rate = -1;
    bool alpha_layer = false;


    static Dictionary get_supported_codecs();
    static Dictionary get_video_file_meta(String file_path);
    static bool is_codec_supported(CODEC codec);


    void set_filename(String new_filename);
    String get_filename();
    
    void set_video_codec(CODEC new_video_codec);
    AVCodecID get_video_codec();
    CODEC get_video_codec_gozen();

    void set_audio_codec(CODEC new_audio_codec);
    AVCodecID get_audio_codec();
    CODEC get_audio_codec_gozen();
 
    void set_video_size(Vector2i new_video_size);
    Vector2i get_video_size();
   
    void set_framerate(int new_framerate);
    int get_framerate();

    void set_bit_rate(int new_bit_rate);
    int get_bit_rate();

    void set_alpha_layer(bool new_alpha_layer);
    bool get_alpha_layer();

    bool check();

  
  protected:
    static inline void _bind_methods() {   
      /* AUDIO CODEC ENUMS */
      BIND_ENUM_CONSTANT(MP3);
      BIND_ENUM_CONSTANT(AAC);
      BIND_ENUM_CONSTANT(OPUS);
      BIND_ENUM_CONSTANT(VORBIS);
      BIND_ENUM_CONSTANT(FLAC);
      BIND_ENUM_CONSTANT(PCM_UNCOMPRESSED);
      BIND_ENUM_CONSTANT(AC3);
      BIND_ENUM_CONSTANT(EAC3);
      BIND_ENUM_CONSTANT(WAV);
      
      /* VIDEO CODEC ENUMS */
      BIND_ENUM_CONSTANT(H264);
      BIND_ENUM_CONSTANT(H265);
      BIND_ENUM_CONSTANT(VP9);
      BIND_ENUM_CONSTANT(MPEG4);
      BIND_ENUM_CONSTANT(MPEG2);
      BIND_ENUM_CONSTANT(MPEG1);
      BIND_ENUM_CONSTANT(AV1);
      BIND_ENUM_CONSTANT(VP8);


      ClassDB::bind_static_method("GoZenRenderProfile", D_METHOD("get_supported_codecs"), &GoZenRenderProfile::get_supported_codecs);
      ClassDB::bind_static_method("GoZenRenderProfile", D_METHOD("is_codec_supported", "codec:CODEC"), &GoZenRenderProfile::is_codec_supported);


      ClassDB::bind_method(D_METHOD("set_filename", "new_filename"), &GoZenRenderProfile::set_filename);
      ClassDB::bind_method(D_METHOD("get_filename"), &GoZenRenderProfile::get_filename);
      
      ClassDB::bind_method(D_METHOD("set_video_codec", "CODEC"), &GoZenRenderProfile::set_video_codec);
      //ClassDB::bind_method(D_METHOD("get_video_codec"), &GoZenRenderProfile::get_video_codec);
      ClassDB::bind_method(D_METHOD("get_video_codec_gozen"), &GoZenRenderProfile::get_video_codec_gozen);

      ClassDB::bind_method(D_METHOD("set_audio_codec", "CODEC"), &GoZenRenderProfile::set_audio_codec);
      //ClassDB::bind_method(D_METHOD("get_audio_codec"), &GoZenRenderProfile::get_audio_codec);
      ClassDB::bind_method(D_METHOD("get_audio_codec_gozen"), &GoZenRenderProfile::get_audio_codec_gozen);
      
      ClassDB::bind_method(D_METHOD("set_video_size", "new_video_size"), &GoZenRenderProfile::set_video_size);
      ClassDB::bind_method(D_METHOD("get_video_size"), &GoZenRenderProfile::get_video_size);
      
      ClassDB::bind_method(D_METHOD("set_framerate", "new_framerate"), &GoZenRenderProfile::set_framerate);
      ClassDB::bind_method(D_METHOD("get_framerate"), &GoZenRenderProfile::get_framerate);
      
      ClassDB::bind_method(D_METHOD("set_bit_rate", "new_bit_rate"), &GoZenRenderProfile::set_bit_rate);
      ClassDB::bind_method(D_METHOD("get_bit_rate"), &GoZenRenderProfile::get_bit_rate);
      
      ClassDB::bind_method(D_METHOD("set_alpha_layer", "new_alpha_layer"), &GoZenRenderProfile::set_alpha_layer);
      ClassDB::bind_method(D_METHOD("get_alpha_layer"), &GoZenRenderProfile::get_alpha_layer);
      
      ClassDB::bind_method(D_METHOD("check"), &GoZenRenderProfile::check);


      ADD_PROPERTY(PropertyInfo(Variant::STRING, "filename"), "set_filename", "get_filename");
      ADD_PROPERTY(PropertyInfo(Variant::VECTOR2I, "video_size"), "set_video_size", "get_video_size");
      ADD_PROPERTY(PropertyInfo(Variant::INT, "framerate"), "set_framerate", "get_framerate");
      ADD_PROPERTY(PropertyInfo(Variant::INT, "bit_rate"), "set_bit_rate", "get_bit_rate");
      ADD_PROPERTY(PropertyInfo(Variant::BOOL, "alpha_layer"), "set_alpha_layer", "get_alpha_layer");
    }
};

VARIANT_ENUM_CAST(GoZenRenderProfile::CODEC);