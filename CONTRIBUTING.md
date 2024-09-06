# Contributing to GoZen

Thank you for considering contributing to the GoZen project! Your help is greatly appreciated in fixing bugs, creating new features, adding to features, improving the editor, and maintaining localization support. This document outlines the guidelines and expectations for contributing to the GoZen project. Please take a moment to review the information below before making any contributions to not waste each others time.

## Project Overview

GoZen is an open-source video editor developed using the Godot game engine (version 4.3). The primary language used is GDScript, with Python and GD extensions (written in C++) also present. The project is licensed under the GPL-3.0 license, this is due to using FFmpeg with the GPL licensed codec support. GoZen will stay open-source, even if we end up moving away from FFmpeg. We will most likely keep the GPL license as I personally feel strongly that this is one of the better licenses, to everybody their own opinion though.

## Getting Started

To contribute to GoZen, make sure you have the following:

- [Godot 4.3](https://godotengine.org/download/);
- [Familiarity with GDScript and Godot](https://docs.godotengine.org/en/stable/);
- Familiarity with C++ could also help for the GDExtension side of things **(not required!)**.

The Godot version will most likely stay the most up to date stable release of Godot unless breaking bugs are present which would stop GoZen from working properly. If this data get's out of date at some point as we moved to a newer version of Godot and I forgot to adjust this, please let me know!

## How to Contribute

1. [Fork the project on GitHub to create your own copy](https://github.com/VoylinsGamedevJourney/GoZen/fork);
1. Create a new branch in your forked repository with a descriptive name for the changes you plan on making;
1. [Open a pull request from your branch to the main repository](https://github.com/VoylinsGamedevJourney/GoZen/compare);
1. Wait for code review and feedback from the project maintainer (you will be notified through the pull request);
1. Address any feedback or requested changes and update your pull request;
1. Once your pull request is approved, it will be merged into the main repository.

If you want to work on multiple things at once, please create multiple branches as merging these changes will otherwise become bothersome to easily search back in the commits of when changes were introduced. So it's better to create multiple PR's if the parts you work on are too different from each other or achieve different goals. If you have questions about this feel free to reach out to the team. ;)

### Reporting Bugs and Requesting Features

For bug reports and feature requests, please follow the guidelines below:

**Bug Reports:** Provide a clear and detailed description of the issue, including steps to reproduce it.
**Feature Requests:** Clearly explain the desired feature and its expected benefits.

### Translation contribution

If you want to contribute with translation, then refer to [translation guide](https://github.com/VoylinsGamedevJourney/GoZen/blob/master/translations/README.md). The translations won't be actively workedon untill the moment before beta! To not spend too much time having to re-do translations I do recommend waiting till we enter the translation phase, more info on this later on.

### Code Reviews and Merging Process

All code reviews and merging will be performed by the project maintainer as right now the project is still mostly a one man job. Once your pull request is submitted, it will go through the following process:

1. The project maintainer will review your changes, providing feedback and suggestions;
1. Make any necessary revisions based on the feedback received;
1. Once your changes meet the project's requirements, they will be merged into the main repository.

Failing to do the necessary revisions will result in your code not being merged, there are exceptions though and that's if someone else wants to take over. But in that case I would mainly prefer that they would fork your branch and make the changes like this as to not have incomplete/non-working code in the project.

## Communication

Discussions and questions related to GoZen can be held on the GitHub Discussions tab or the project's [Discord server](https://discord.gg/BdbUf7VKYC).

## Additional Resources

Currently, no specific coding conventions, style guidelines, documentation, tutorials, guidelines for writing tests, or code of conduct are available. These resources will be developed and added over time. However, your contributions are still highly encouraged and appreciated.

Best advice is to just look at the coding style being used and replicate it, I will work more on this part of the guidelines after entering the beta stage.

