#!/bin/bash

install_dir="$1"
spack "${SPACK_VERBOSE[@]}" install "${SPACK_NO_CACHE}" gcc@10.2.0 ^binutils+ld+gold~nls+gas 
compilers_yaml="$install_dir/spack/etc/spack/compilers.yaml"
fix_compiler="$REPO_ROOT/bin/fix_compiler"

# gcc@10.2.0
spack load gcc@10.2.0
spack compiler find --scope=site 
binutils_path=$(spack find --loaded --long -p | grep binutils | awk '{ print $3 }')/bin
${fix_compiler} "$compilers_yaml" edit gcc@10.2.0 rhel7 x86_64\
    --env="PATH+=${binutils_path}"
spack unload -a 


