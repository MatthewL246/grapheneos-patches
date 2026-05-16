# My personal GrapheneOS patches

This repository contains build scripts and patches I use for my personal [GrapheneOS](https://grapheneos.org) builds.

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
- The [chenxiaolong/grapheneos-patches repo](https://github.com/chenxiaolong/grapheneos-patches), which provided me with some inspiration for this project (although I don't directly use any code from it)
- [Hacker News comments from the GrapheneOS founder](https://news.ycombinator.com/threads?id=strcat) (unfortunately, I don't have specific links, but this is how I learned about the "ADB-only root" method, and I want to give credit where credit is due)
