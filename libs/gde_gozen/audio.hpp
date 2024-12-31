#pragma once

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/core/math.hpp>

#include "ffmpeg.hpp"


using namespace godot;

class Audio : public Resource {
	GDCLASS(Audio, Resource);

public:
	static PackedByteArray get_audio_data(String a_path);

	static PackedByteArray combine_data(PackedByteArray a_one, PackedByteArray a_two);

	static PackedByteArray change_db(PackedByteArray a_data, float a_db);
	static PackedByteArray change_to_mono(PackedByteArray a_data, bool a_left);

	static inline void _log(String a_message) {
		UtilityFunctions::print("Renderer: ", a_message, ".");
	}
	static inline bool _log_err(String a_message) {
		UtilityFunctions::printerr("Renderer: ", a_message, "!");
		return false;
	}

protected:
	static inline void _bind_methods() {
		ClassDB::bind_static_method("Audio", D_METHOD("get_audio_data", "a_file_path"), &Audio::get_audio_data);

		ClassDB::bind_static_method("Audio", D_METHOD("combine_data", "a_one", "a_two"), &Audio::combine_data);

		ClassDB::bind_static_method("Audio", D_METHOD("change_db", "a_data", "a_db"), &Audio::change_db);
		ClassDB::bind_static_method("Audio", D_METHOD("change_to_mono", "a_data", "a_left"), &Audio::change_db);
	}
};
