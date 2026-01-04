#pragma once

#include "ffmpeg.hpp"
#include "ffmpeg_helpers.hpp"

#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>
#include <godot_cpp/classes/audio_stream_playback_resampled.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/mutex.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>


using namespace godot;


class AudioStreamFFmpeg : public AudioStream {
	GDCLASS(AudioStreamFFmpeg, AudioStream);

  private:
	// FFmpeg classes.
	UniqueAVFormatCtxInput av_format_ctx;
	UniqueAVCodecCtx av_codec_ctx;
	UniqueAVIOContext avio_ctx;
	UniqueSwrCtx swr_ctx;
	AVStream* av_stream = nullptr;

	AVChannelLayout ch_layout;
	BufferData buffer_data; // Used for res:// and user://
	PackedByteArray file_buffer;

	bool loaded = false;
	bool stereo = true;
	int bytes_per_sample = 0;
	int sample_rate = 44100;
	double length = 0;

	Mutex *mutex; // We need thread safety

	String file_path;

	static inline void _log(String message) { UtilityFunctions::print("GoZenAudioStream: ", message, "."); }
	static inline bool _log_err(String message) {
		UtilityFunctions::printerr("GoZenAudioStream: ", message, "!");
		return false;
	}

  public:
	AudioStreamFFmpeg() = default;
	~AudioStreamFFmpeg();

	int open(const String& path, int stream_index = -1);
	void close();
	inline bool is_open() const { return loaded; }

	double _get_length() const override { return length; }
	bool _is_monophonic() const override { return !stereo; }

	Ref<AudioStreamPlayback> _instantiate_playback() const override;

  protected:
	static void _bind_methods();
	friend class AudioStreamFFmpegPlayback;
};

class AudioStreamFFmpegPlayback : public AudioStreamPlaybackResampled {
	GDCLASS(AudioStreamFFmpegPlayback, AudioStreamPlaybackResampled);

  private:
	const AudioStreamFFmpeg* audio_stream_ffmpeg = nullptr;
	UniqueAVFrame av_frame;
	UniqueAVFrame av_decoded_frame;
	UniqueAVPacket av_packet;

	struct sint16_stereo {
		int16_t l;
		int16_t r;
	};

	sint16_stereo* buffer = nullptr;
	size_t buffer_len = 4410000 * 6; // ~1 minute
	size_t buffer_fill = 0;			 // Number of samples current in buffer
	bool is_playing = false;

	uint32_t mixed = 0;
	uint32_t mix_rate = 44100;
	bool stereo = true;

  public:
	AudioStreamFFmpegPlayback() {
		buffer = new sint16_stereo[buffer_len];

		if (!av_packet)
			av_packet = make_unique_ffmpeg<AVPacket, AVPacketDeleter>(av_packet_alloc());
		if (!av_frame)
			av_frame = make_unique_ffmpeg<AVFrame, AVFrameDeleter>(av_frame_alloc());
		if (!av_decoded_frame)
			av_decoded_frame = make_unique_ffmpeg<AVFrame, AVFrameDeleter>(av_frame_alloc());
	}
	~AudioStreamFFmpegPlayback() override { delete[] buffer; }

	bool fill_buffer();

	void _start(double p_from_pos) override;
	void _stop() override;
	bool _is_playing() const override;
	int32_t _get_loop_count() const override { return 0; }
	double _get_playback_position() const override;
	void _seek(double p_position) override;
	int32_t _mix_resampled(AudioFrame* p_buffer, int32_t p_frames) override;
	float _get_stream_sampling_rate() const override { return mix_rate; }

  protected:
	static inline void _bind_methods() {}
	friend class AudioStreamFFmpeg;
};
