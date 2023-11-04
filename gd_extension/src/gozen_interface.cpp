#include "gozen_interface.hpp"

#include <godot_cpp/variant/utility_functions.hpp>

#include <iostream>
#include <fstream>
#include <sstream>
#include <cstdlib>


void GoZenInterface::get_thumb(String file_path, String dest_path) {
  UtilityFunctions::print("Path of file is:");
  UtilityFunctions::print(file_path);
}

void GoZenInterface::_bind_methods() {
  ClassDB::bind_method(D_METHOD("get_thumb"), &GoZenInterface::get_thumb, "file_path", "dest_path");
  //ClassDB::bind_method(D_METHOD("get_first_frame", "arg1"))
}