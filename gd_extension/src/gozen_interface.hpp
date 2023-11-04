#ifndef GOZEN_INTERFACE_HPP
#define GOZEN_INTERFACE_HPP

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/builtin_types.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

class GoZenInterface : public Resource {
  GDCLASS(GoZenInterface, Resource);

  public:
    GoZenInterface() {}
    ~GoZenInterface() {}

    void get_thumb(String file_path, String dest_path);


  protected:
    static void _bind_methods();
};

#endif