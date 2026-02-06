# Contributing to GoZen 🤝
Thank you for considering contributing to the GoZen project, all help is greatly appreciated!

This document outlines the guidelines for contributing to the GoZen project. Please take a moment to review the information below, before making your first contribution.

## Ways to contribute
There are many ways you can contribute to the GoZen project:
- Report bugs you find whilst using GoZen;
- Suggest new features and/or enhancements;
- Write code (implement features, fix bugs, improve performance);
- Improve documentation;
- Provide feedback on the UI and experience;
- Help testing new releases to guarantee a stable experience;
- Contribute financially (see below);
- Spread the word of GoZen!

## Getting help & Communication
If you have questions, need clarification, or want to discuss ideas before contributing, please join our [Discord server](https://discord.gg/BdbUf7VKYC). It's the best place for real-time communication with the community and maintainers. Issues can also be created in the repo itself.

## Reporting bugs 🐛
Found a bug (which is still alive)? Please help us by reporting it!

1. Go to the [Issues tab](https://github.com/VoylinsGamedevJourney/gozen/issues);
1. Click the "New Issue" button;
1. Choose the **Bug Report** template;
1. Provide a clear and detailed description of the issue, including:
    * Steps to reproduce the bug;
    * Expected behaviour;
    * Actual behaviour;
    * Version of GoZen you are using;
    * The prompt which got printed in the terminal (if possible);
1. Including screenshots or a short video could help a lot (but not required);

## Suggesting features
Have an (awesome) idea for a new feature or improvement? We'd love to hear and consider it!

1. Go to the [Issues tab](https://github.com/VoylinsGamedevJourney/gozen/issues);
1. Click the "New Issue" button;
1. Choose the **Feature Request** template;
1.  Clearly explain your suggestion, including:
    *   The problem you're trying to solve.
    *   Your proposed solution.
    *   How it would benefit users.
    *   Any alternative ideas you considered.

> [!IMPORTANT]
> For larger features, it's recommended to discuss them on the [Discord server](https://discord.gg/BdbUf7VKYC).

## Contributing code
We welcome code contributions! Please follow these steps to make contributions go more smoothly:

### Project overview
GoZen is an open-source video editor developed using the Godot game engine (we follow the stable version releases). The primary languages used are GDScript and C++ (for the GDExtension). The project is licensed under the GPL-3.0 license, partly due to the use of FFmpeg with the GPL-compatible codecs. GoZen will stay open-source under the GPL license, even if we end up moving away from FFmpeg since most libraries for handling video files fall under this license anyway.

### Setting up your development enviroment
1. **Prerequisites:**
    * Get the latest stable version of [the Godot Engine](https://godotengine.org);
    * Install git;
    * Familiarity with GDScript and Godot workflow ([Godot Docs](https://docs.godotengine.org/en/stable/));
    * (Optional) Familiarity with C++ and GDExtension if you plan on working on the GDE GoZen part of the editor;
    * (Optional) knowledge of video/audio formats and FFmpeg can be helpful;
1. **Fork the repo:**
    * [Fork the GoZen project from GitHub](https://github.com/VoylinsGamedevJourney/GoZen/fork) to create your own copy of GoZen to work in;
    * Clone your fork to your local machine
1. **Build the GDE:**
    * Run `build.py` with python3 from the main project folder;
    * Follow the steps to build for your system (choose debug);
1. **Open project in Godot:**
    * Opening the project can be done through launching Godot and opening the project which is inside the `src` folder.

### Your first code contribution
1. Make certain you have pulled all commits from upstream and that you are inside of the `master` branch;
1. Create a new branch with a descriptive name related to the feature or bug fix you want to implement;
1. Make your changes, write your code, fix bugs, ...;
1. Test your changes, be certain that it doesn't break anything else and that it works as expected;
1. Follow the coding style, there's no document yet outlining the style so base it upon the other scripts for now;
1. Write a clear commit message about the change you made;
1. Commit and push your changes, afterwards create a pull request;

From there we will review the code and test it ourselves as well. If everything is okay, we merge the PR. If not, we will ask for some changes to happen. Once merged: Congratulations, you've contributed to GoZen!

## Documentation contributions
Improving documentation (README, code comments, Godot docs, Wiki) is a valuable contribution! If you see something unclear or missing, feel free to open an issue or submit a pull request with your proposed changes.

## UI/UX feedback
Since GoZen is a visual editor, feedback on the user interface and experience is very helpful, especially given the "minimalist" goal. Open issues to provide feedback or suggestions.

## Translations
Translation contributions are not yet necessary due to the early alpha stage, but we plan to add support for internationalization in the future. Stay tuned!

## Financial contributions
If you want to support GoZen financially, you can do so via Ko-fi. This helps support my overall work, including GoZen development, videos, and other projects.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/voylin)

Thank you again for your interest and support!
