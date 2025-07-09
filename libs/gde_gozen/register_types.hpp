#pragma once

#include <gdextension_interface.h>

#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/core/class_db.hpp>

#include "gozen_video.hpp"
#include "gozen_audio.hpp"
#include "gozen_encoder.hpp"

using namespace godot;


void initialize_gozen_library_init_module();
void uninitialize_gozen_library_init_module();

