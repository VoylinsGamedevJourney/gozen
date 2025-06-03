#pragma once

#include <cstdint>
#include <cmath>

#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include "ffmpeg.hpp"
#include "ffmpeg_helpers.hpp"


using namespace godot;

class Video : public Resource {
	GDCLASS(Video, Resource);

private:
	// FFmpeg classes
	UniqueAVFormatCtxInput av_format_ctx;
	UniqueAVCodecCtx av_codec_ctx;
	AVStream *av_stream = nullptr;

	UniqueAVPacket av_packet;
	UniqueAVFrame av_frame;

	UniqueAVFrame av_sws_frame;
	UniqueSwsCtx sws_ctx;

	// Default variable types
	int response = 0;

	int current_frame = -1;
	Ref<Image> y_data;
	Ref<Image> u_data;
	Ref<Image> v_data;

	int64_t start_time_video = 0;
	int64_t frame_timestamp = 0;
	int64_t current_pts = 0;

	double average_frame_duration = 0;
	double stream_time_base_video = 0;

	bool loaded = false; // Is true after open()
	bool using_sws = false; // This is set for when the pixel format is foreign and not directly supported by the addon
	
	int sws_flag = SWS_BILINEAR;

	// Metadata variables
	String path = "";

	Vector2i resolution = Vector2i(0,0);
	float framerate = 0.0;
	int64_t duration_us = 0; // Duration in microseconds.
	int64_t frame_count = 0; // Amount of video frames.
	
	int rotation = 0; // Rotation in degrees (0, 90, 180, 270).
	int padding = 0;
	
	String pixel_format_name = "";
	String color_primaries_name = "";
	String color_trc_name = "";
	String color_space_name = "";

	bool is_full_color_range = false; // Limited (tv) or full (pc) range.
	bool is_interlaced = false;

	// Private functions
	void _copy_frame_data();
	int _seek_frame(int frame_nr);

	static inline void _log(const String& message) {
		UtilityFunctions::print("Video: ", message, ".");
	}
	static inline bool _log_err(const String& message) {
		UtilityFunctions::printerr("Video: ", message, "!");
		return false;
	}

public:
	Video();
	~Video();

	bool open(const String& video_path);
	void close();

	inline bool is_open() { return loaded; }

	bool seek_frame(int frame_nr);
	bool next_frame(bool skip_frame = false);

	Ref<Image> generate_thumbnail_at_frame(int frame_nr);

	inline void set_sws_flag_bilinear() { sws_flag = SWS_BILINEAR; }
	inline void set_sws_flag_bicubic() { sws_flag = SWS_BICUBIC; }

	inline int get_current_frame() const { return current_frame; }
	inline Ref<Image> get_y_data() const { return y_data; }
	inline Ref<Image> get_u_data() const { return u_data; }
	inline Ref<Image> get_v_data() const { return v_data; }

	// Metadata getters
	inline String get_path() const { return path; }

	inline Vector2i get_resolution() const { return resolution; }
	inline int get_width() const { return resolution.x; }
	inline int get_height() const { return resolution.y; }

	inline float get_framerate() const { return framerate; }
	inline int get_frame_count() const { return static_cast<int>(frame_count); }
	inline int64_t get_duration_microseconds() const { return duration_us; }
	inline double get_duration_seconds() const { return static_cast<double>(duration_us) / 1000000.0; }
	inline int get_rotation() const { return rotation; }
	inline int get_padding() const { return padding; }

	inline String get_pixel_format_name() const { return pixel_format_name; }
	inline String get_color_primaries_name() const { return color_primaries_name; }
	inline String get_color_trc_name() const { return color_trc_name; }
	inline String get_color_space_name() const { return color_space_name; }

	inline bool get_is_full_color_range() const { return is_full_color_range; }
	inline bool get_is_interlaced() const { return is_interlaced; }

protected:
	static void _bind_methods();
};

