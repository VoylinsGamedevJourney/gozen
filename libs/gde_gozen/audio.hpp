#pragma once

#include <cmath>

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/core/math.hpp>

#include "ffmpeg.hpp"
#include "ffmpeg_helpers.hpp"


using namespace godot;

class Audio : public Resource {
	GDCLASS(Audio, Resource);

private:
	static PackedByteArray _get_audio(AVFormatContext *&format_ctx,
									  AVStream *&stream, bool wav);

	static inline void _log(String message) {
		UtilityFunctions::print("Audio: ", message, ".");
	}
	static inline bool _log_err(String message) {
		UtilityFunctions::printerr("Audio: ", message, "!");
		return false;
	}

public:
	static PackedByteArray get_audio_data(String file_path);

	static PackedByteArray combine_data(PackedByteArray audio_one,
										PackedByteArray audio_two);

	static PackedByteArray change_db(PackedByteArray audio_data, float db);
	static PackedByteArray change_to_mono(PackedByteArray audio_data,
										  bool left);

protected:
	static void _bind_methods();
};
