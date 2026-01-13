<img src="icons/icon.png?raw=true" width="128" height=128>

# VNDS-LOVE-TOUCH

VNDS-LOVE-TOUCH is a fork of VNDS-LOVE designed to work with touchscreens, particularly iPadOS devices.

VNDS-LOVE is a cross platform program that plays **V**isual **N**ovel **D**ual **S**creen formatted novels.
Many famous visual novels have been ported to this format, which was designed for the Nintendo DS.

## What is VNDS?

VNDS is a specification designed for visual novels in order to run them on the Nintendo DS. Many of the original sources for the project no longer exist, but you can find further information on it [at this wiki page.](https://github.com/BASLQC/vnds/wiki)

VNDS novels only have a few commands. As such, they don't have any support for animations, videos, or other fancier graphical capabilites of newer visual novels. They support basic audio and image based storytelling.

## Project Status

Mostly functional. There are no known VNDS related bugs. Note that some features from other visual novel engines might be missing. If they are, file an issue along with a general description of the feature.

## Supported Platforms

iOS, iPadOS

# Installation Instructions

Add the AltStore repository to your LiveContainer/SideStore/AltStore for automatic updates: `https://github.com/OctoNezd/VNDS-LOVE-TOUCH/releases/latest/download/altStoreManifest.json`

Install .ipa file from [actions](https://nightly.link/OctoNezd/VNDS-LOVE-TOUCH/workflows/main/main/artifact) using [AltStore](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) or jailbreak/trollstore.

## Having an Issue?

Go to the [issues](https://github.com/octonezd/VNDS-LOVE-TOUCH/issues/) and search for an issue similar to yours.
If there are no similar issues, go ahead and make a new one! Fill out as much information as you can.

# Development Instructions

ONLY FOLLOW THESE INSTRUCTIONS IF YOU WANT TO COMPILE VNDS-LOVE!
IF YOU JUST WANT TO PLAY VISUAL NOVELS, GO TO THE GUIDE!

You should be able to develop on Windows, Mac, and Linux. However, to compile the game for iOS you would need a Mac. If you encounter any errors when trying to do that, [create an issue.](https://github.com/octonezd/VNDS-LOVE-TOUCH/issues/new)

## Quickstart

If you are an experienced developer, try reading through the Dockerfile and the main.yml workflow in the repository to get an idea of how the entire thing is built. If you want step by step instructions, follow along below.

## Guide

1. Install [LuaRocks](https://luarocks.org/)
2. After making sure that LuaRocks is on your path (`luarocks --help` has output), run the following:

```
luarocks install moonscript --local
luarocks install busted --local
luarocks install alfons --local
```

3. Clone the repository (`git clone https://github.com/octonezd/VNDS-LOVE-TOUCH`)
4. `cd` to the cloned directory (`cd VNDS-LOVE-TOUCH`)
5. Install [development version of Love2D](https://github.com/love2d/love/actions) and make sure it is also on your path.

Run `alfons compile` to compile the moonscript source to lua.

Run `alfons run` to run VNDS-LOVE using the installed copy of `love`.

Run `alfons test` to run the busted unit tests, which are located in `spec`

## Building

Building binaries requires additional steps.
If you are able to run VNDS-LOVE with changes using Love2D, you do not need to build the program.
You can submit a [Pull Request](https://github.com/octonezd/VNDS-LOVE-TOUCH/pulls) without building the program.
Building is just for distribution.

With that out of the way:

### Building for Windows, Mac, and Linux

1. Try running `luarocks install --server=http://luarocks.org/dev love-release`
2. Install `libzip-dev` on your OS if the above command fails.
3. Run `alfons build`, and the build files should appear in a `build` folder, including a `.love` file.

### Building for iOS

See .github/workflows/main.yml
