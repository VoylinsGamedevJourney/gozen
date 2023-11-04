#ifndef GOZEN_INTERFACE_REGISTER_TYPES_HPP
#define GOZEN_INTERFACE_REGISTER_TYPES_HPP

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void initialize_gozen_interface_library_init_module(ModuleInitializationLevel p_level);
void uninitialize_gozen_interface_library_init_module(ModuleInitializationLevel p_level);

#endif