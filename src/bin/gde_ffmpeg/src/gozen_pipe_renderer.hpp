#pragma once
// Basic render system which uses ffmpeg command to render.
// For this method, ffmpeg needs to be installed on the system.

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/builtin_types.hpp>


using namespace godot;

class GoZenPipeRenderer : public Resource {
  GDCLASS(GoZenPipeRenderer, Resource);
  
  private:
    FILE* ffmpegPipe;

  public:
    GoZenPipeRenderer() {}
    ~GoZenPipeRenderer() {}

    void setup(String output, int frame_rate);
    void add_frame(Ref<Image> frame_image);
    void finish_video();

    void add_audio(String input_video, String input_audio, bool shortest_stream = true);

  protected:
    static void _bind_methods() {
      ClassDB::bind_method(D_METHOD("setup", "output:String", "frame_rate:int"), &GoZenPipeRenderer::setup);
      ClassDB::bind_method(D_METHOD("add_frame", "frame_image:Image"), &GoZenPipeRenderer::add_frame);
      ClassDB::bind_method(D_METHOD("finish_video"), &GoZenPipeRenderer::finish_video);
      ClassDB::bind_method(D_METHOD("add_audio", "input_video:String", "input_audio:String", "shortest_stream:bool"), &GoZenPipeRenderer::add_audio);
    }
};