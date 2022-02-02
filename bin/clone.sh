#!/bin/bash

target_subdir="backend/installations"
dest_subdir="backend/installations"

function usage() {
    echo "clone.sh [-u] <target> <dest>"
    echo "Clone a TCE environment from process.sh install path <target> to <dest>, "
    echo "creating symlinks to all installed packages. This allows you to use <dest> "
    echo "as an install target for process.sh, reusing packages built at <target> "
    echo "without modifying them."
    echo "Packages and existing symlinks in dest are left as is."
    echo 
    echo "  -u     Update all symlinks if they already exist."
    echo "  -t <subdir> The target subdirectory path under which spack installs "
    echo "              packages. Defaults to $target_subdir"
    echo "              Requires an argument: if source has no subdirectory for "
    echo "              package installations, use '.' as the argument."
    echo "  -d <subdir> The dest subdirectory path under which clone.sh links "
    echo "              packages.  Defaults to $dest_subdir"
    echo "              Requires an argument: if no subdirectory is intended "
    echo "              for package installation destination, use '.' as the argument."
    exit 1
}

non_comp_dirs="bin"

while getopts "ut:d:" opt; do
    case $opt in 
    u)
        update=true;;
    t)
        target_subdir=$OPTARG;;
    d)
        dest_subdir=$OPTARG;;
    *)
        usage;;
    esac
done

target=${*:$OPTIND:1}
dest=${*:$OPTIND+1:1}

if ! [[ -d "$target" ]]; then
    echo "Target directory '$target' does not exist."
    exit 1
fi

echo "Cloning from $target to $dest."

if ! [[ -d "$dest" ]]; then
    if ! mkdir -p "$dest"; then 
        echo "Could not create destination directory '$dest'"
    fi
fi

src_path=${target}/${target_subdir}
for compiler in "${src_path}"/*; do
    [ -d "${compiler}" ] || continue  
    [[ "${compiler//*\/}" =~ ${non_comp_dirs} ]] && continue

    echo "Cloning packages built by ${compiler//*\/}"

    for build in "${compiler}"/*; do
        tpath="${build}"
        dbase="${dest}/${dest_subdir}/${compiler//*\/}"
        dpath="${dbase}/${build//*\/}"

        if [[ -L "$dpath" ]]; then 
            continue
        elif [[ -d "$dpath" ]]; then
            if [[ $update == true ]]; then
                echo -n "Updating '${compiler}."
                rm -rf "$dpath"
                ln -s "$tpath" "$dpath"
            fi
        else
            echo "Creating link to build '${build}'."
            mkdir -p "$dbase"
            ln -s "$tpath" "$dpath"
        fi
    done
done
