#! /usr/bin/env bash

# Instructions: https://grapheneos.org/build

set -euo pipefail

emulator_target="sdk_phone64_x86_64-cur-user"
phone_codename="blazer"
phone_target="$phone_codename-cur-user"

function check_build_dependencies {
    target="$1"

    for dependency in repo python3 git gpg ssh-keygen diff fc-list hostname openssl rsync unzip zip node yarn; do
        command -v "$dependency" >/dev/null || (echo "Missing dependency: $dependency" && exit 1)
    done

    # freetype2 dependency doesn't have an executable, but it's probably installed considering how many things depend on it

    if [[ ! -d ./grapheneos ]]; then
        echo "Error: $(pwd)/grapheneos source code directory not found. Copy or symlink it in the root of this repo."
        echo "Or, create the $(pwd)/grapheneos directory now if you *really* want to re-download >100GB of code."
        exit 1
    fi

    if [[ "$target" == "$phone_target" && (! -d "./grapheneos/keys/$phone_codename" || "$(find "./grapheneos/keys/$phone_codename" -type f | wc -l)" -ne 22) ]]; then
        echo "Error: Release signing keys not found. Generate them by following https://grapheneos.org/build#generating-release-signing-keys"
        exit 1
    fi
}

function update_source_code {
    update_version="$1"

    repo init --manifest-url https://github.com/GrapheneOS/platform_manifest.git --manifest-branch "refs/tags/$update_version"

    # If they change their keys for some reason, manual intervention should be necessary
    cd .repo/manifests
    git config gpg.ssh.allowedSignersFile ../../../allowed_signers
    git verify-tag "$(git describe)"
    cd ../..

    # More than about 16 jobs results in rate limit errors
    # Force options may result in loss of data, but all of that data should be saved as patches
    repo sync --jobs 16 --force-sync --force-checkout --force-remove-dirty --prune --auto-gc

    # These are read by envsetup.sh to set some metadata about the build date and time
    # For cleaner builds, it might be better to always delete these, but it adds a few minutes to incremental builds because some of the later targets (like partition images) need to be regenerated
    # So, it seems like a good compromise to only delete them when updating
    if [[ -f ./out/build_date.txt ]]; then
        rm ./out/build_date.txt
    fi
    if [[ -f ./out/soong/build_number.txt ]]; then
        rm ./out/soong/build_number.txt
    fi
}

function update_patches {
    # This previously reset all of the repos and then applied all patches indiscriminately, but that method invalidated the incremental build cache!

    function apply_patch {
        patch_file="$(realpath --no-symlinks "$1")"
        # https://stackoverflow.com/a/28523143
        relative_patch_path="$(realpath --no-symlinks --relative-to ../patches "$patch_file")"

        pushd "$(dirname "$relative_patch_path")" >/dev/null

        # https://stackoverflow.com/a/66755317
        if git apply --reverse --check "$patch_file" >/dev/null 2>&1; then
            echo "Patch $relative_patch_path already applied"
        else
            echo "Applying patch $relative_patch_path"
            git apply "$patch_file"
        fi

        popd >/dev/null
    }

    find ../patches -type f -iname "*.patch" -print0 |
        while read -r -d $'\0' patch; do
            apply_patch "$patch"
        done
}

function run_build {
    target="$1"

    # Android build system scripts reference undefined variables
    set +u
    source ./build/envsetup.sh
    set -u

    # Directory name will need to change when new releases update the vendor firmware version
    if [[ "$target" == "$phone_target" && ! -d "./vendor/adevtool/dl/unpacked/$phone_codename-CP1A.260505.005" ]]; then
        yarn --cwd ./vendor/adevtool install --immutable --ignore-scripts
        # This invalidates a few parts of the incremental build cache (about 3-4 minutes to rebuild)
        ./vendor/adevtool/bin/run generate-all --devices "$phone_codename"
    fi

    set +u
    lunch "$target"
    set -u

    if [[ "$target" == "$emulator_target" ]]; then
        m -j "$(nproc)"
        emulator
    elif [[ "$target" == "$phone_target" ]]; then
        m -j "$(nproc)" vendorbootimage vendorkernelbootimage target-files-package otatools-package

        read -r -p "Build completed, continue generating a signed release? (y/N) " response
        if [[ "$response" == y || "$response" == Y ]]; then

            # Max I saw was about 13GB, but increase it a little to be safe
            fallocate --length 15G /tmp/free-space-test || read -r -p "Error: could not create a 15GB test file in /tmp. Generating the release will fail. Fix the problem and then continue." _
            rm -f /tmp/free-space-test

            ./script/finalize.sh
            # Variables are set by envsetup.sh
            ./script/generate-release.sh "$TARGET_PRODUCT" "$BUILD_NUMBER"

            echo
            echo "Finished! Files are in $(realpath "./releases/$BUILD_NUMBER/release-$TARGET_PRODUCT-$BUILD_NUMBER")"
        fi
    else
        echo "Error: not sure what build command to run"
        exit 1
    fi
}

function main {
    base_dir="$(dirname "$(realpath "$0")")"
    cd "$base_dir"

    if [[ $# -lt 1 || "$1" =~ ^-?-?h(elp)?$ ]]; then
        echo "Usage: $0 <target> [version]"
        echo
        echo "<target> must be \"phone\" or \"emulator\"."
        echo "[version] may be the latest release tag name from https://grapheneos.org/releases#$phone_codename. If specified, the source code will be updated to that version, which will reset all local changes. Otherwise, no update will be performed."

        [[ $# -lt 1 ]] && exit 1 || exit 0
    fi

    target=""
    update_version=""

    if [[ "$1" == phone ]]; then
        target="$phone_target"
    elif [[ "$1" == emulator ]]; then
        target="$emulator_target"
    else
        echo "Invalid target provided."
        exit 1
    fi

    if [[ -n "${2:-}" ]]; then
        update_version="$2"
    fi

    check_build_dependencies "$target"

    cd ./grapheneos

    if [[ -n "$update_version" ]]; then
        update_source_code "$update_version"
    fi

    update_patches

    run_build "$target"
}

main "$@"
