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

class GoZenVideo : public Resource {
	GDCLASS(GoZenVideo, Resource);

private:
	// FFmpeg classes
	UniqueAVFormatCtxInput av_format_ctx;
	UniqueAVCodecCtx av_codec_ctx;
	AVStream *av_stream = nullptr;

	UniqueAVPacket av_packet;
	UniqueAVFrame av_frame;
	UniqueAVFrame av_sws_frame;
	UniqueSwsCtx sws_ctx;

	enum AVColorPrimaries color_profile;

	// Default variable types.
	int response = 0;
	int current_frame = 0;
	int padding = 0;

	int8_t rotation = 0;
	int8_t interlaced = 0; // 0 = no interlacing, 1 = interlaced top first, 2 interlaced bottom first
	
	int64_t duration = 0;
	int64_t frame_count = 0;

	int64_t start_time_video = 0;
	int64_t frame_timestamp = 0;
	int64_t current_pts = 0;

	double average_frame_duration = 0;
	double stream_time_base_video = 0;

	float sar = 0;
	float framerate = 0;

	bool loaded = false; // Is true after open()
	bool using_sws = false; // This is set for when the pixel format is foreign and not directly supported by the addon
	bool full_color_range = true;
	
	int sws_flag = SWS_BILINEAR;

	// Godot classes.
	String path = "";
	String pixel_format = "";

	Vector2i resolution = Vector2i(0,0);
	Vector2i actual_resolution = Vector2i(0,0);

	Ref<Image> y_data;
	Ref<Image> u_data;
	Ref<Image> v_data;
	
	// Private functions
	void _copy_frame_data();
	void _clean_frame_data();
	int _seek_frame(int frame_nr);

	static inline void _log(const String& message) {
		UtilityFunctions::print("GoZenVideo: ", message, ".");
	}
	static inline bool _log_err(const String& message) {
		UtilityFunctions::printerr("GoZenVideo: ", message, "!");
		return false;
	}

public:
	GoZenVideo();
	~GoZenVideo();

	bool open(const String& video_path);
	void close();
	static Dictionary get_file_meta(String a_file_path);

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
	inline Vector2i get_actual_resolution() const { return actual_resolution; }
	inline int get_width() const { return resolution.x; }
	inline int get_height() const { return resolution.y; }
	inline int get_actual_width() const { return actual_resolution.x; }
	inline int get_actual_height() const { return actual_resolution.y; }

	inline float get_framerate() const { return framerate; }
	inline int get_frame_count() const { return static_cast<int>(frame_count); }
	inline int get_rotation() const { return rotation; }
	inline int get_padding() const { return padding; }
	inline int get_interlaced() const { return interlaced; }
	inline float get_sar() const { return sar; }

	inline String get_pixel_format() const { return pixel_format; }
	inline String get_color_profile() { return av_color_primaries_name(color_profile); }

	inline bool get_full_color_range() const { return full_color_range; }

protected:
	static void _bind_methods();
};

