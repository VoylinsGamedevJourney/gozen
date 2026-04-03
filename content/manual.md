+++
title = 'GoZen User Manual'
description = 'Learn how to use the GoZen video editor'
date = 2026-04-03
draft = false
+++

## 1. Interface Overview
- **File Panel**: Manage your media assets (videos, audio, images, text, and solid colors);
- **Timeline**: Arrange and cut your clips. Features multiple tracks for layering;
- **View Panel**: Preview your video, control playback, and scrub through frames;
- **Effects Panel**: Tweak properties, add visual/audio effects, and animate with keyframes;
- **Render Screen**: Configure export settings and generate your final video;

## 2. Basic Editing
- **Importing Media**: Drag and drop files directly into the editor, or use the **Add files** button in the file panel;
- **Adding to Timeline**: Drag a file from the File Panel onto a track in the Timeline at the bottom;
- **Timeline Modes**:
  - **Select Mode (S)**: Click to select clips, drag edges to trim, and drag the body to move them around;
  - **Cut Mode (X)**: Click on a clip to split it at the cursor's position;
- **Deleting**: Select a clip and press `Delete` to remove it. Press `Shift + Delete` for a ripple delete (automatically closes the empty gap);

## 3. Working with Effects
When a clip is selected, its properties appear in the **Effects Panel** on the right side.
- Click the **+** (Add) icon in the Visual or Audio header to apply a new effect;
- **Keyframes**: Click the diamond icon next to a parameter to create a keyframe. This allows you to animate values over time (e.g., panning a transform, fading a drop shadow, or zooming);
- **Fading**: Hover over the edges of a clip in the timeline to reveal fade handles. Drag them inward to quickly create visual or audio fades;

## 4. Rendering Your Video
Once you are happy with your edit, switch to the **Render** screen at the top left.
- **Profiles**: Select a pre-configured profile like `YouTube`, `AV1`, or `High Quality` for a quick setup;
- **Export Path**: Choose where to save your final video file (`.mp4`, `.webm`, etc.);
- **Advanced**: Tweak video/audio codecs, CRF (quality), GOP size, and multi-threading depending on your machine and preferences;
- Click **Start render** to export your masterpiece!

## 5. Shortcuts & Timeline Inputs
GoZen features a variety of shortcuts and mouse inputs to speed up your editing workflow.

### Global Shortcuts
- **Play / Pause**: `Space` or `K`
- **Next Frame**: `Right Arrow` or `L`
- **Previous Frame**: `Left Arrow` or `J`
- **Save Project**: `Ctrl + S`
- **Save Project As**: `Ctrl + Shift + S`
- **Open Project**: `Ctrl + O`
- **Undo / Redo**: `Ctrl + Z` / `Ctrl + Y`
- **Switch Screen (Edit/Render)**: `Ctrl + Tab`
- **Open Command Bar**: `/` (Slash)
- **Open Editor Settings**: `Ctrl + Shift + .`
- **Open Project Settings**: `Ctrl + .`
- **Help / About**: `F1`

### Timeline Shortcuts
- **Select Mode**: `S`
- **Cut Mode**: `X`
- **Cut Clip(s) at Playhead**: `Ctrl + K`
- **Cut Clip(s) at Mouse**: `Ctrl + Shift + K`
- **Delete Selected Clip(s)**: `Delete`
- **Ripple Delete Clip(s)**: `Shift + Delete` *(Deletes the clip and closes the gap)*
- **Duplicate Selected Clip(s)**: `Ctrl + D`
- **Remove Empty Space**: `T` *(Or Double-Click empty space)*
- **Add / Edit Marker**: `G`

### Timeline Mouse Inputs
- **Zoom Timeline**: `Ctrl + Mouse Wheel`
- **Scroll Horizontal**: `Mouse Wheel`
- **Scroll Vertical**: `Shift + Mouse Wheel`
- **Box Select Clips**: `Shift + Left Click & Drag`
- **Trim Clip**: `Left Click & Drag` on the left or right edges of a clip.
- **Change Clip Speed**: `Ctrl + Left Click & Drag` on the edges of a clip.
- **Fade Clip (Visual/Audio)**: `Left Click & Drag` on the inner corners of a clip. *(Top corners for Audio fades, Bottom corners for Video/Visual fades).*
- **Expand Fade Handles**: Hold `Shift` while hovering to make the fade handles larger and easier to grab.
- **Context Menu**: `Right Click` on a clip or empty space to reveal more options.

### Effects & Keyframe Inputs
- **Move Keyframe**: `Left Click & Drag` a keyframe on the effect track.
- **Copy Keyframe**: `Ctrl + Left Click & Drag` a keyframe.
- **Preserve Existing Values**: `Alt + Left Click & Drag` *(Overrides existing keyframes at the target frame instead of ignoring them).*
- **Delete Keyframe**: `Right Click` on a keyframe.
