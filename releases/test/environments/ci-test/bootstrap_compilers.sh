#!/bin/bash
set -e

install_dir=$1
fix_compiler="${REPO_ROOT}/bin/fix_compiler"
compilers_yaml="${install_dir}/spack/etc/spack/compilers.yaml"

echo "Adding gcc@10.2.0 to the Spack env."
spack "${SPACK_VERBOSE[@]}" add "${SPACK_NO_CACHE}" gcc@10.2.0 ^binutils+ld+gold~nls+gas

echo "Concretizing after adding gcc@10.2.0."
spack "${SPACK_VERBOSE[@]}" concretize

echo "Installing gcc@10.2.0 in the Spack env."
spack "${SPACK_VERBOSE[@]}" install "${SPACK_NO_CACHE}" gcc@10.2.0 ^binutils+ld+gold~nls+gas

spack "${SPACK_VEBOSE[@]}" load "${SPACK_NO_CACHE}" gcc@10.2.0 ^binutils+ld+gold~nls+gas

spack compiler find --scope=site
echo "Setting binutils_path"
binutils_path=$(spack find --loaded --long -p | grep binutils | awk '{ print $3 }')/bin
${fix_compiler} "$compilers_yaml" gcc@10.2.0 rhel7 x86_64 edit --env="PATH+=${binutils_path}"

echo "Unloading Spack env(?)"
spack unload -a 


