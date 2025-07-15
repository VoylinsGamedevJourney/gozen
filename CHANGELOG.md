# Changelog
This is the changelog of all releases which can be found on the [GoZen repo release page](https://github.com/VoylinsGamedevJourney/gozen/releases)

## Version 0.4-alpha - 2025/**/**
### Added
- RPM build;
- DEB build;
- GIF playback;
- De-interlacing support;
- SAR support (non-square pixels);
- Rotation by default (for videos with rotation tag);
- On quit dialog when unsaved changes are present;
- Error when trying to add +3 hour 23 minutes videos (2GB array limitation audio);
- Support for Forward+ (but compatibility mode is faster in most cases);
- Local clip video instancing;
- Option to save screenshots (and add to project);
- Timeline bar with timestamps;

### Fixed
- Light theme having unreadable menu buttons;
- "About GoZen" popup is now a "popup";
- Some translation strings;
- Pure Linux build crash on startup;
- File panel popup not showing;
- Seeking video would skip 1 frame;
- Thumbnailer sizing not working well for non 9:16 aspect ratio;

### Improved
- Windows workflow takes less time;
- Better indication for screen buttons;
- Cut down Workflow build time by 60%;
- Locale getter on first launch;
- Better cleanup for faster closing of GoZen;
- Thumbnailer now uses cache folder;


## Version 0.3-alpha - 2025/07/05
Big thanks to https://github.com/ManpreetXSingh for the massive PR which fixed and added a lot of encoding capabilities and for the improvements on the build system!
Also a big thank you to all the translators, some languages aren't fully up to date, but that's my fault for going too fast and adding too many strings on a weekly/daily basis.

### Added
- Update notification system;
- Sponsor segment on start screen on startup;
- Image files from clipboard support;
- Render screen; (instead of popup)
- Extra debug information;
- File panel got replaced with a file tree;
- Added a render manager; (Autoload)
- Support dropping folders in GoZen;
- Support for marker skipping; (Markers coming in a next update)
- Color objects can now be created/used;
- Undo/Redo for file interactions;
- Extra Undo/Redo for timeline interactions;
- Clip snapping;
- Auto save for projects;
- **Thumbnails:**
    - Video;
    - Audio;
    - Color objects;
- **Encoder/Decoders:**
    - Container format: ogg;
    - libx264;
    - libx264rgb;
    - libx265;
    - libsvtav1;
    - libaom-av1;
    - libvpx-vp9;
    - libvpx-vpx (vp8);
    - libmp3lame;
    - libvorbis;
    - libopus;
- **Localization:**
    - Localization support got added (PO file system);
    - English (Source) - by [Voylin](https://github.com/voylin);
    - Chinese (Traditional) - by [aappaapp](https://github.com/Aappaapp);
    - Dutch - by [Voylin](https://github.com/Voylin);
    - Spanish - by [Dekotale](https://github.com/dekotale);
    - French - by [Slander](https://github.com/Slander), [#Guigui](https://github.com/HastagGuigui);
    - German - by [flipdp](https://github.com/flipdp);
    - Japanese - by [Voylin](https://github.com/Voylin);
    - Urdu - by [AdilDevStuff](https://github.com/AdilDevStuff);
- **Loading screens:**
    - Loading screen when opening projects;
    - New project creation progress overlay;
    - File loading progress overlay;

### Fixed
- **Rendering/Encoding:**
    - Rendered video not having correct image;
    - Rendering for Windows;
    - Rendering for certain Linux distro's;
    - Last frames not being flushed to video file when rendering;
- **Clips:**
    - Clips can overlap each other on the timeline (Cutting issue);
    - Clip frame displaying after end of clip;
    - Clip cutting with selected clips;
    - Resizing clips not behaving as expected;
- Thumbnails are always generated, if exist or not;
- Videos not loading correctly and replacing previously added videos;
- Timeline zooming;
- Translations in command bar;
- File dropping having issues;
- Timeline behaviour;
- Audio encoding fix;
- Audio playback fix;
- Splash screen fix;

### Improved
- Render debug info;
- File loading;
- Clip cutting now works with selected clips;
- Change submodules from ssh to https;
- New build system; - https://github.com/VoylinsGamedevJourney/gozen/pull/136
- Menu bar;
- Toolbox is now static; (instead of Autoload)
- Class renaming of GDE GoZen for improved compatibility with plugins and custom modules;
- Render profiles got updated with better settings;
- Audio encoding became faster;
- Video rendering became much faster;
- Dark/Light theme got improved to fit the new UI;
- CI Build system got improved;
- Tons of UI tweaks;
- Settings and Project Settings menu got a big update;

### Removed
- Metadata settings for rendering videos;


## Version 0.2.3-alpha - 2025/05/14
A small update with the star of the show: Rendering should be fixed. Also, localization is implemented and will soon accept contributors to add the extra languages.


## Version 0.2.2-alpha - 2025/05/11
### Added
- .desktop file;
- GoZen icon file;
- CHANGELOG.md file;
- Extra debug prints;
- Way to change the SWS flag; (only available to developer for now)

### Fixed
- GDExtension dependency paths;
- Effects tab not opening on first clip click;
- Double click being triggered in wrong area;
- Zooming in on the timeline; (Fixed but there's a small amount of "lag" when zooming in now)
- Scroll speed for the timeline;
- Files list not opening tab with loaded files on startup;

### Improved
- Updating project markdown files;
- Build size for compiling full build by limiting FFmpeg dependencies;
- Update README.md;
- Update CONTRIBUTING.md;
- Changed the project to compatibility mode for more hardware support;


## Version 0.2.1-alpha - 2025/05/01
### Added
- Open project with path as argument;
- Save project as;
- Emergency argument to reset settings (reset_settings);
- About GoZen popup;
- Top bar (with the option to hide it);
- Delete empty track spaces;
- Use arrow key's to go between frames;
- File modified time check on refocusing the project widow;
- Audio waveforms to previews in timeline;

### Fixed
- Cancel render button not working if something went wrong;
- Seek frame error for temporary unavailable resource;
- Image cutting/resizing in timeline;
- Resizing wasn't precise;
- Window doesn't start maximized;
- Clips being completely white when having them selected (after resize);
- Videos with thumbnails not loading properly;
- Default project settings not being applied;

### Improved
- Reduce Linux export size (by fixing symlinks);
- Remember + set previous zoom/scroll on project loading;
- Audio wave forms;
- Make it possible to use delete shortcut on files;
- Deleting files should be part of the undo/redo system;


## Version 0.2-alpha - 2025/04/27
### Added
- Dragging in folders with files;
- Cancel button on Render progress window;
- Error when something goes wrong during rendering;
- End screen for rendering process;
- Render setting for changing amount of cores/threads for encoding;
- Setting for pause after dragging option;
- Splash screen;
- Indicator for frame nr + timestamp of playhead;
- Clip debug print (Ctrl+click on selected clip to get debug info printed in terminal);

### Fixed
- Video playback (full color video);
- Timeline lines not fully expanding;
- Have the mouse cursor change on the resize handles of clips;
- Files can be added multiple times;
- Audio mute mutes entire track;
- Scrolling on clips opens clip effects;
- Rendering audio from multiple tracks not working;
- Mute not working for rendered audio;
- Ctrl+K cutting all clips instead of only the selected clip;

### Improved
- Timeline scroll speed;
- Hide the files box buttons when empty;
- Scrolling on timeline to mouse cursor position;
- Video loading;
- The render progress window for showing more accurately of what's happening;


## Version 0.1.3-alpha - 2025/04/22
- *Fix:* Render menu crashes GoZen on opening for some people;


## Version 0.1.2-alpha - 2025/04/21
### Added
- Window title updates after creating/opening a project;

### Fixed
- Render menu crashing;
- Disappearing view when cutting clips;
- Audio timeline ghosting;
- Aspect ratio bug in view;


## Version 0.1.1-alpha - 2025/04/21
- *Fix:* Bug which made creating new projects not possible;


## Version 0.1-alpha - 2025/05/21
This update had basic functionality, would be difficult to list all things for this release since it was the very beginning which had all kind of stuff added to it.

