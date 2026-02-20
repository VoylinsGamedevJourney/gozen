#pragma once

#include "audio.hpp"
#include "audio_stream_ffmpeg.hpp"
#include "encoder.hpp"
#include "video.hpp"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;


void initialize_gozen_library_init_module();
void uninitialize_gozen_library_init_module();
