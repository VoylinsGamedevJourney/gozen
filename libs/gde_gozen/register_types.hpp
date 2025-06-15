#pragma once

#include <gdextension_interface.h>

#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/core/class_db.hpp>

#include "video.hpp"
#include "audio.hpp"
#include "encoder.hpp"

using namespace godot;


void initialize_gozen_library_init_module();
void uninitialize_gozen_library_init_module();

