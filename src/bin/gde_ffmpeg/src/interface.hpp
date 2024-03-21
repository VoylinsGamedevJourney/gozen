#pragma once

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include "ffmpeg_includes.hpp"


using namespace godot;


class GoZenInterface : public Resource {
	GDCLASS(GoZenInterface, Resource);

	public:
		enum CODEC {
			MP3 = AV_CODEC_ID_MP3,			/* Audio codecs */
			AAC = AV_CODEC_ID_AAC,
			OPUS = AV_CODEC_ID_OPUS,
			VORBIS = AV_CODEC_ID_VORBIS,
			FLAC = AV_CODEC_ID_FLAC,
			PCM_UNCOMPRESSED = AV_CODEC_ID_PCM_S16LE,
			AC3 = AV_CODEC_ID_AC3,
			EAC3 = AV_CODEC_ID_EAC3,
			WAV = AV_CODEC_ID_WAVPACK,
			H264 = AV_CODEC_ID_H264,		/* Video codecs */
			H265 = AV_CODEC_ID_HEVC,
			VP9 = AV_CODEC_ID_VP9,
			MPEG4 = AV_CODEC_ID_MPEG4,
			MPEG2 = AV_CODEC_ID_MPEG2VIDEO,
			MPEG1 = AV_CODEC_ID_MPEG1VIDEO,
			AV1 = AV_CODEC_ID_AV1,
			VP8 = AV_CODEC_ID_VP8 
		};

		static Dictionary get_supported_codecs();
		static Dictionary get_video_file_meta(String file_path);
		static bool is_codec_supported(CODEC codec);

	
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
 
			ClassDB::bind_static_method("GoZenInterface", D_METHOD("get_supported_codecs", "filename:String"), &GoZenInterface::get_supported_codecs);
			ClassDB::bind_static_method("GoZenInterface", D_METHOD("get_video_file_meta", "file_path:String"), &GoZenInterface::get_video_file_meta);
			ClassDB::bind_static_method("GoZenInterface", D_METHOD("is_codec_supported", "codec:CODEC"), &GoZenInterface::is_codec_supported);
		}
};

VARIANT_ENUM_CAST(GoZenInterface::CODEC);
