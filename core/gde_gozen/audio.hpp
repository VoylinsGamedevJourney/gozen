#pragma once

#include "encoder.hpp"
#include "ffmpeg.hpp"
#include "smb_pitch_shift.hpp"

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <unordered_map>


using namespace godot;



class Audio : public Resource {
	GDCLASS(Audio, Resource);

  private:
	static PackedByteArray _get_audio(AVFormatContext*& format_ctx, AVStream*& stream, double start_time,
									  double duration);

	static inline bool _log_err(String message) {
		UtilityFunctions::printerr("Audio: ", message, "!");
		return false;
	}

	UniqueAVFormatCtxInput format_ctx_inst;
	UniqueAVCodecCtx codec_ctx_inst;
	UniqueSwrCtx swr_ctx_inst;
	UniqueAVIOContext avio_ctx_inst;
	BufferData buffer_data_inst;
	PackedByteArray file_buffer_inst;
	PackedByteArray leftover_buffer_inst;
	AVStream* stream_inst = nullptr;
	int bytes_per_sample_inst = 0;
	bool loaded = false;
	double last_returned_time = -1.0;

  public:
	static PackedByteArray get_audio_data(String file_path, int stream_index, double start_time, double duration);

	static PackedByteArray combine_data(PackedByteArray audio_one, PackedByteArray audio_two, int offset_bytes = 0);

	static PackedByteArray change_db(PackedByteArray audio_data, float db);
	static PackedByteArray change_to_mono(PackedByteArray audio_data, bool left);
	static PackedByteArray change_speed(PackedByteArray audio_data, float speed);

	static PackedByteArray apply_dynamic_volume(PackedByteArray audio_data, PackedFloat32Array frame_volumes,
												float mix_rate, float framerate);

	static PackedByteArray apply_fade(PackedByteArray audio_data, int fade_in_samples, int fade_out_samples,
									  int start_sample = 0, int total_samples = 0);

	static PackedByteArray apply_pan(PackedByteArray audio_data, float pan);
	static PackedByteArray apply_channel_swap(PackedByteArray audio_data);
	static PackedByteArray apply_stereo_to_mono(PackedByteArray audio_data);
	static PackedByteArray apply_retro_filter(PackedByteArray audio_data, int bit_depth);
	static PackedByteArray apply_pitch(PackedByteArray audio_data, float pitch_scale);

	Error open(String file_path, int stream_index = -1);
	PackedByteArray get_audio_data_chunk(double start_time, double duration);
	void close();

  protected:
	static void _bind_methods();
};
