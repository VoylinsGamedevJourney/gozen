#include "gozen_interface.hpp"

#include <godot_cpp/variant/utility_functions.hpp>

#include <iostream>
#include <fstream>
#include <sstream>
#include <cstdlib>


void GoZenInterface::get_thumb(String file_path, String dest_path) {
  UtilityFunctions::print_rich("[b]GoZenInterface:[/b] Generating thumbnail for " + file_path);

  // FFmpeg command to extract the first frame
  std::string path_file = file_path.utf8().get_data();
  std::string path_dest = dest_path.utf8().get_data();
  std::string ffmpegCommand = "ffmpeg -i " + path_file + " -vf \"select=eq(n\\,0)\" -vframes 1 " + path_dest;

  int status = std::system(ffmpegCommand.c_str());

  if (status != 0) {
    UtilityFunctions::print_rich("[b]GoZenInterface:[/b] Thumb created successfully!");
  } else {
    UtilityFunctions::printerr("Error extracting the first frame.");
  }
}

void GoZenInterface::_bind_methods() {
  ClassDB::bind_method(D_METHOD("get_thumb"), &GoZenInterface::get_thumb, "file_path", "dest_path");
  //ClassDB::bind_method(D_METHOD("get_first_frame", "arg1"))
}