#include "gozen_interface.hpp"

#include <godot_cpp/variant/utility_functions.hpp>

#include <mlt++/Mlt.h>


void GoZenInterface::get_thumb(String file_path, String dest_path) {
  UtilityFunctions::print_rich("[b]GoZenInterface:[/b] Generating thumbnail for " + file_path);
  std::string path_file = file_path.utf8().get_data();
  std::string path_dest = dest_path.utf8().get_data();
  
  
}

void GoZenInterface::_bind_methods() {
  ClassDB::bind_method(D_METHOD("get_thumb"), &GoZenInterface::get_thumb, "file_path", "dest_path");
}
