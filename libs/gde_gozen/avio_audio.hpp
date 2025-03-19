#pragma once


#include <godot_cpp/variant/utility_functions.hpp>

#include "ffmpeg.hpp"


using namespace godot;


class AvioAudio {
private:
	const uint8_t *wav_data;
	size_t wav_size;
	size_t position;

	int response = 0;


	static int read_packet(void *a_opaque, uint8_t *a_buf, int a_buf_size);
	static int64_t seek_packet(void *a_opaque, int64_t a_offset, int a_whence);


public:
	AvioAudio(const uint8_t *a_data, size_t a_size);
	~AvioAudio();

	AVFormatContext *create_avformat_context();

};
