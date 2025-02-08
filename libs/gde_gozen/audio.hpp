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


using namespace godot;

class Audio : public Resource {
	GDCLASS(Audio, Resource);

private:
	static PackedByteArray _get_audio(AVFormatContext *&a_format_ctx, AVStream *&a_stream, bool a_wav);

	static inline void _log(String a_message) {
		UtilityFunctions::print("Renderer: ", a_message, ".");
	}
	static inline bool _log_err(String a_message) {
		UtilityFunctions::printerr("Renderer: ", a_message, "!");
		return false;
	}
	
	PackedByteArray raw_data;
	PackedByteArray data;
	Ref<AudioStreamWAV> stream;

public:
	static PackedByteArray get_audio_data(String a_path);
	static Ref<ImageTexture> get_audio_wave(PackedByteArray a_data, int a_framerate);

	static PackedByteArray combine_data(PackedByteArray a_one, PackedByteArray a_two);

	inline void reset_data() {
		if (!stream.is_valid()) {
			stream.instantiate();
			stream->set_format(godot::AudioStreamWAV::FORMAT_16_BITS);
			stream->set_stereo(true);
			stream->set_mix_rate(44100);
		}
		data = raw_data.duplicate();
		stream->set_data(data); };

	inline void set_raw_data(PackedByteArray a_data) {
			raw_data = a_data;
			reset_data(); }
	inline PackedByteArray get_raw_data() { return raw_data; }
	inline int get_raw_data_size() { return raw_data.size(); }

	inline Ref<AudioStreamWAV> get_stream() { return stream; }
	inline PackedByteArray get_data() { return data; }
	inline int get_data_size() { return data.size(); }

	void change_db(float a_db);
	void change_to_mono(bool a_left);


protected:
	static inline void _bind_methods() {
		ClassDB::bind_static_method("Audio", D_METHOD("get_audio_data", "a_file_path"), &Audio::get_audio_data);
		ClassDB::bind_static_method("Audio", D_METHOD("get_audio_wave", "a_data", "a_framerate"), &Audio::get_audio_wave);

		ClassDB::bind_static_method("Audio", D_METHOD("combine_data", "a_one", "a_two"), &Audio::combine_data);

		ClassDB::bind_method(D_METHOD("reset_data"), &Audio::reset_data);
		ClassDB::bind_method(D_METHOD("set_raw_data", "a_data"), &Audio::set_raw_data);
		ClassDB::bind_method(D_METHOD("get_raw_data"), &Audio::get_raw_data);
		ClassDB::bind_method(D_METHOD("get_raw_data_size"), &Audio::get_raw_data_size);

		ClassDB::bind_method(D_METHOD("get_stream"), &Audio::get_stream);
		ClassDB::bind_method(D_METHOD("get_data"), &Audio::get_data);
		ClassDB::bind_method(D_METHOD("get_data_size"), &Audio::get_data_size);

		ClassDB::bind_method(D_METHOD("change_db", "a_db"), &Audio::change_db);
		ClassDB::bind_method(D_METHOD("change_to_mono", "a_left"), &Audio::change_to_mono);
	}
};
