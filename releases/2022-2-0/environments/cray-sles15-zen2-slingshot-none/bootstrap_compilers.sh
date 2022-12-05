#!/bin/bash
set -e

install_dir=$1
fix_compiler="${REPO_ROOT}/bin/fix_compiler" # REPO_ROOT provided by wrapper
compilers_yaml="${install_dir}/spack/etc/spack/compilers.yaml"

echo "Checking for compilers under PrgEnv-cray"
spack compiler find --scope=site

module switch PrgEnv-cray PrgEnv-intel

echo "Checking for compilers under PrgEnv-intel"
spack compiler find --scope=site

# Spack finds the intel compilers completely incorrectly. 
IFX=$(which icx)
ICPX=$(which icpx)

#Only ever do this once.
if ! grep 'intel@2021.7.1.classic' $compilers_yaml; then 
    # The compilers are detected at the compiler version (ie, correctly) rather than the package
    # version.
    # The intel-classic compiler is detected as intel (hybrid)
    # Spack doesn't recognize a compiler named intel-classic, so we just add a 'c' to the version. 
    $fix_compiler "$compilers_yaml"  intel@2021.7.1 sles15 x86_64 copy intel@2022.2.1
    $fix_compiler "$compilers_yaml"  intel@2021.7.1 sles15 x86_64 edit --rename intel@2021.7.1.classic

    # The intel compiler is just like the classic one, except different.
    $fix_compiler "$compilers_yaml"  intel@2022.2.1 sles15 x86_64 edit --cc="$IFX" --cxx="$ICPX"

    # The version of oneapi is correct too, so we have to 'fix' it.
    # $fix_compiler "$compilers_yaml"  oneapi@2022.0.0 sles15 x86_64 edit --rename oneapi@2022.0.2
fi

module switch PrgEnv-intel PrgEnv-gnu

echo "Checking for compilers under PrgEnv-gnu"
spack compiler find --scope=site

echo "Explicitly adding GCC 11.2.0"
module swap gcc gcc/11.2.0
spack compiler find --scope=site

if ! spack compiler list | grep 'gcc@11\.2\.0'; then 
    echo "Could not find gcc@11.2.0"
    exit 1
fi

