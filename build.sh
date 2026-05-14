#! /usr/bin/env bash

# Instructions: https://grapheneos.org/build

set -euo pipefail

function check_build_dependencies {
    for dependency in repo python3 git gpg ssh-keygen diff fc-list hostname openssl rsync unzip zip node yarn; do
        command -v "$dependency" >/dev/null || (echo "Missing dependency: $dependency" && exit 1)
    done

    # freetype2 dependency doesn't have an executable, but it's probably installed considering how many things depend on it

    if [[ ! -d ./grapheneos ]]; then
        echo "Error: $(pwd)/grapheneos source code directory not found. Copy or symlink it in the root of this repo."
        echo "Or, create the $(pwd)/grapheneos directory now if you *really* want to re-download >100GB of code."
        exit 1
    fi
}

function update_source_code {
    update_version="$1"

    repo init --manifest-url https://github.com/GrapheneOS/platform_manifest.git --manifest-branch "refs/tags/$update_version"

    # If they change their keys for some reason, manual intervention should be necessary
    if [[ ! -f ./allowed_signers ]]; then
        curl https://grapheneos.org/allowed_signers --remote-name
    fi

    cd .repo/manifests
    git config gpg.ssh.allowedSignersFile ../../allowed_signers
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
    # Needed so the patches apply cleanly
    repo forall --jobs "$(nproc)" --command git reset --hard >/dev/null

    function apply_patch {
        patch_file="$(realpath --no-symlinks "$0")"
        repo_path="$(dirname "$(realpath --no-symlinks --relative-to ../patches "$patch_file")")"

        echo "Applying patch $patch_file"
        cd "$repo_path"
        git apply "$patch_file"
    }

    export -f apply_patch
    find ../patches -type f -iname "*.patch" -exec bash -c 'apply_patch "$0"' {} \;
    export -nf apply_patch
}

function main {
    base_dir="$(dirname "$(realpath "$0")")"
    cd "$base_dir"

    if [[ $# -lt 1 || "$1" =~ ^-?-?h(elp)?$ ]]; then
        echo "Usage: $0 <target> [version]"
        echo
        echo "<target> must be \"phone\" or \"emulator\"."
        echo "[version] may be the latest release tag name from https://grapheneos.org/releases#blazer. If specified, the source code will be updated to that version, which will reset all local changes. Otherwise, no update will be performed."

        [[ $# -lt 1 ]] && exit 1 || exit 0
    fi

    target=""
    update_version=""

    if [[ "$1" == phone ]]; then
        target="blazer-cur-user"
    elif [[ "$1" == emulator ]]; then
        target="sdk_phone64_x86_64-cur-user"
    else
        echo "Invalid target provided."
        exit 1
    fi

    if [[ -n "${2:-}" ]]; then
        update_version="$2"
    fi

    check_build_dependencies

    cd ./grapheneos

    if [[ -n "$update_version" ]]; then
        update_source_code "$update_version"
    fi

    update_patches
}

main "$@"
