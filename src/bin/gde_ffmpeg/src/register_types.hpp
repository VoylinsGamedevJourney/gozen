#pragma once

#include <godot_cpp/core/class_db.hpp>

#include <gdextension_interface.h>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_gozen_library_init_module(ModuleInitializationLevel p_level);
void uninitialize_gozen_library_init_module(ModuleInitializationLevel p_level);
