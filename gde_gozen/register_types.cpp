#include "register_types.hpp"

using namespace godot;

#include "video.hpp"
#include "renderer.hpp"


void initialize_gozen_library_init_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) 
		return;
	
	ClassDB::register_class<Video>();
	ClassDB::register_class<Renderer>();
}


void uninitialize_gozen_library_init_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) 
		return;
}


extern "C" {
	// Initialization
	GDExtensionBool GDE_EXPORT
	gozen_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
		GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
		
		init_obj.register_initializer(initialize_gozen_library_init_module);
		init_obj.register_terminator(uninitialize_gozen_library_init_module);
		init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

		return init_obj.init();
	}
}
