# My personal GrapheneOS patches

This repository contains build scripts and patches I use for my personal [GrapheneOS](https://grapheneos.org) builds.

## Important note about installing for the first time

The patch [`script/only-generate-ota-update-in-generate-release-script.patch`](./patches/script/only-generate-ota-update-in-generate-release-script.patch) deliberately prevents the release generation step from generating an install zip, which is used to install the OS on a device for the first time. Make sure to disable the patch (i.e. change the file extension to `.patch.disabled`) before running the build script for the first time. Then, after installing and relocking the bootloader, enable it again to save some time when generating updated releases.

## Goals

- Build GrapheneOS from source and sign it with keys that I control. This allows me to make changes to the OS without unlocking the bootloader or wiping data.
- Add support for ADB-only root, which allows the `adb root` command in production (user) builds but does not provide any sort of app-accessible root or `su` binary. My understanding (based on comments by the developers) is that this is the only rooting method that does not break the OS's security model.

### Future Goals

- Add some way to enable or disable `adb root` at runtime.
- Add support for OTA updates from a custom server.
- Potentially add more patches.

## Disadvantages

TODO: there are several disadvantages to using this, including not getting security preview releases.

## Resources

- [Official GrapheneOS build instructions](https://grapheneos.org/build)
- [GrapheneOS releases](https://grapheneos.org/releases)
- The [chriswoope/resign-android-image repo](https://github.com/chriswoope/resign-android-image), which provided me with some inspiration this project, information about the implications of signing my own GrapheneOS images, and ideas for patches (although I don't directly use any code from it, as it is based on modifying official OTA images instead of building them from source)
- The [chenxiaolong/avbroot repo](https://github.com/chenxiaolong/avbroot), which is a similar project based on modifying official OTA images (it seems more polished than the previous repo but accomplishes root by installing Magisk, which is not what I am personally looking for)
- The [chenxiaolong/grapheneos-patches repo](https://github.com/chenxiaolong/grapheneos-patches), which also provided me with some inspiration for this project and ideas for patches (although I don't directly use any of its patches)
- [Hacker News comments from the GrapheneOS founder](https://news.ycombinator.com/threads?id=strcat) (unfortunately, I don't have specific links, but this is how I learned about the "ADB-only root" method and why GrapheneOS is explicitly against other forms of rooting, and I want to give credit where credit is due)
