# Compiling GoZen

This guide will help you compile the GoZen GDExtension.

## Step 1: Installing dependencies

### Linux

- For dependencies you will mainly need Python and SCons. These are needed for compiling the GDExtension which gives access to FFmpeg, which also needs to be installed.

    ```bash
    pacman -Syu python scons ffmpeg
    ```
### Windows

- Install MSYS2 from [www.msys2.org](https://www.msys2.org/)
- Add `path\to\msys64\mingw64\bin` and `path\to\msys64\usr\bin` to the `Path` environment variable. The default installation path is `C:\msys64\`

- Update all packages by executing the following command in the terminal:

    ```bash
    pacman -Suy
    ```

    **Note:** In some cases pacman will prompt you to close all terminals. After confiming start a new terminal and re-run the above command.

- Install the required dependencies using the following command:

    ```bash
    pacman -S mingw-w64-cross-binutils mingw-w64-x86_64-toolchain mingw-w64-x86_64-scons mingw-w64-x86_64-yasm diffutils make
    ```

## Step 2: Cloning repositories

- Open a terminal in the desired directory and clone the GoZen repository

    ```bash
    git clone --recurse-submodules https://github.com/VoylinsGamedevJourney/GoZen.git
    ```

- Move to the GoZen directory

    ```bash
    cd GoZen
    ```

- Clone the godot-cpp repository

    ```bash
    git clone https://github.com/godotengine/godot-cpp.git src/bin/gde_ffmpeg/godot-cpp
    ```

## Step 3: Compiling and editing the project

- Execute the build script

    ```bash
    sh build.sh
    ```

    **Note:** You will need to compile FFmpeg at least once. Enter `y` when prompted.

- Once the build is complete, you can now open the Godot project located in `./src` directory

    ```bash
    cd src && /path/to/godot -e .
    ```
