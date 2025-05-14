# Changelog
This is the changelog of all releases which can be found on the [GoZen repo release page](https://github.com/VoylinsGamedevJourney/gozen/releases)

## Version 0.2.3-alpha - 2025/05/14
A small update with the star of the show: Rendering should be fixed.
Also, localization is implemented and will soon accept contributors to add the extra languages.

## Version 0.2.2-alpha - 2025/05/11
### Fixes
- *Fix:* GDExtension dependency paths;
- *Fix:* Effects tab not opening on first clip click;
- *Fix:* Double click being triggered in wrong area;
- *Fix:* Zooming in on the timeline; (Fixed but there's a small amount of "lag" when zooming in now)
- *Fix:* Scroll speed for the timeline;
- *Fix:* Files list not opening tab with loaded files on startup;
### Additions
- *Add:* .desktop file;
- *Add:* GoZen icon file;
- *Add:* CHANGELOG.md file;
- *Add:* Extra debug prints;
- *Add:* Way to change the SWS flag; (only available to developer for now)
### Improvements
- *Improved:* Updating project markdown files;
- *Improved:* Build size for compiling full build by limiting FFmpeg dependencies;
- *Improved:* Update README.md;
- *Improved:* Update CONTRIBUTING.md;
- *Improved:* Changed the project to compatibility mode for more hardware support;

## Version 0.2.1-alpha - 2025/05/01
### Fixes
- *Fix:* Cancel render button not working if something went wrong;
- *Fix:* Seek frame error for temporary unavailable resource;
- *Fix:* Image cutting/resizing in timeline;
- *Fix:* Resizing wasn't precise;
- *Fix:* Window doesn't start maximized;
- *Fix:* Clips being completely white when having them selected (after resize);
- *Fix:* Videos with thumbnails not loading properly;
- *Fix:* Default project settings not being applied;
### Additions
- *Add:* Open project with path as argument;
- *Add:* Save project as;
- *Add:* Emergency argument to reset settings (reset_settings);
- *Add:* About GoZen popup;
- *Add:* Top bar (with the option to hide it);
- *Add:* Delete empty track spaces;
- *Add:* Use arrow key's to go between frames;
- *Add:* File modified time check on refocusing the project widow;
- *Add:* Audio waveforms to previews in timeline;
### Improvements
- *Improved:* Reduce Linux export size (by fixing symlinks);
- *Improved:* Remember + set previous zoom/scroll on project loading;
- *Improved:* Audio wave forms;
- *Improved:* Make it possible to use delete shortcut on files;
- *Improved:* Deleting files should be part of the undo/redo system;


## Version 0.2-alpha - 2025/04/27
### Fixes
- *Fix:* Video playback (full color video);
- *Fix:* Timeline lines not fully expanding;
- *Fix:* Have the mouse cursor change on the resize handles of clips;
- *Fix:* Files can be added multiple times;
- *Fix:* Audio mute mutes entire track;
- *Fix:* Scrolling on clips opens clip effects;
- *Fix:* Rendering audio from multiple tracks not working;
- *Fix:* Mute not working for rendered audio;
- *Fix:* Ctrl+K cutting all clips instead of only the selected clip;
### Additions
- *Add:* Dragging in folders with files;
- *Add:* Cancel button on Render progress window;
- *Add:* Error when something goes wrong during rendering;
- *Add:* End screen for rendering process;
- *Add:* Render setting for changing amount of cores/threads for encoding;
- *Add:* Setting for pause after dragging option;
- *Add:* Splash screen;
- *Add:* Indicator for frame nr + timestamp of playhead;
- *Add:* Clip debug print (Ctrl+click on selected clip to get debug info printed in terminal);
### Improvements
- *Improved:* Timeline scroll speed;
- *Improved:* Hide the files box buttons when empty;
- *Improved:* Scrolling on timeline to mouse cursor position;
- *Improved:* Video loading;
- *Improved:* The render progress window for showing more accurately of what's happening;

## Version 0.1.3-alpha - 2025/04/22
- *Fix:* Render menu crashes GoZen on opening for some people;

## Version 0.1.2-alpha - 2025/04/21
### Fixes
- *Fix:* Render menu crashing;
- *Fix:* Disappearing view when cutting clips;
- *Fix:* Audio timeline ghosting;
- *Fix:* Aspect ratio bug in view;
### Addition
- *Add:* Window title updates after creating/opening a project;

## Version 0.1.1-alpha - 2025/04/21
- *Fix:* Bug which made creating new projects not possible;

## Version 0.1-alpha - 2025/05/21
This update had basic functionality, would be difficult to list all things for this release since it was the very beginning which had all kind of stuff added to it.

