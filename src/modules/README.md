# GoZen Modular System
The GoZen modular system is designed to allow developers and users to extend the editing experience and feel without having to alter the project's core source code. Modules can give you new UI panels, visual/audio effects, transitions, custom scenes (PCK clips), and UI themes.

## 1. Module Locations
Modules are loaded from two primary locations:
* **Built-in (Local):** `res://modules/` - Modules shipped with the editor;
* **User Installed (Global):** `user://modules/` - Modules installed by the user via `.pck` files.

## 2. The `GoZenModule` Resource
Every module is defined by a `module.tres` file at its root, which uses the `GoZenModule` class. This resource acts as the config file for the module and contains:
- **Metadata:** `name`, `description`, `author`, `version`, and `settings`.
- **Content Arrays:**
    - `custom_panels`: Array of `GoZenModulePanel` (injects UI into the WorkspaceManager);
    - `custom_scenes`: Array of `GoZenModuleScene` (allows PCK clips to run custom Godot scenes on the timeline);
    - `custom_themes`: Array of `GoZenModuleTheme` (adds custom look-and-feel themes);
    - `custom_effects`: Array of `GoZenModuleEffect` (injects new Audio/Visual effects);
    - `custom_transitions`: Array of `GoZenModuleTransition` (injects custom transitions);

## 3. The Loading Pipeline (`ModuleManager.gd`)
During the editor's startup (`_enter_tree`), the `ModuleManager` autoload takes care of following tasks:
1. **Config Loading:** First it reads the `user://modules_config.json` file to check which user-installed modules are enabled/disabled;
1. **PCK Mounting:** It iterates through the global user modules. If enabled, it uses `ProjectSettings.load_resource_pack()` to mount the PCK into the virtual `res://` file system;
1. **Resource Scanning:** It scans `res://modules/` for any directories containing a `module.tres` file and stores them in memory;
1. **Registration:**
    - Panels are made available to `WorkspaceManager`;
    - Effects and Transitions are made available to `EffectsHandler`;
    - Themes are added to `Settings.custom_themes`;

## 4. User Module Installation
Users can install external modules via the Module Manager UI (Preferences > Module manager). When a `.pck` is selected:
1. The file is physically copied to `user://modules/`;
1. It is added to the `modules_config.json` and marked as enabled;
1. A restart is should not be required (but depends on the module and the functionality it adds);
