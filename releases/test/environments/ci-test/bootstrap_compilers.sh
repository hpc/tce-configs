#!/bin/bash

install_dir="$1"
compilers_yaml="$install_dir/spack/etc/spack/compilers.yaml"
fix_compiler="$REPO_ROOT/bin/fix_compiler"

if grep -q 'release-3' /etc/toss-release; then
    echo "Adding gcc@10.2.0 to the spack env."
    spack "${SPACK_VERBOSE[@]}" add "${SPACK_NO_CACHE}" gcc@10.2.0 ^binutils+ld+gold~nls+gas 

    echo "Concretizing after adding gcc@10.2.0."
    spack "${SPACK_VERBOSE[@]}" concretize

    echo "Installing gcc@10.2.0 in the spack env."
    spack "${SPACK_VERBOSE[@]}" install "${SPACK_NO_CACHE}" gcc@10.2.0 ^binutils+ld+gold~nls+gas 

    echo "Loading gcc@10.2.0 in the spack env."
    spack "${SPACK_VERBOSE[@]}" load "${SPACK_NO_CACHE}" gcc@10.2.0 ^binutils+ld+gold~nls+gas 

    spack compiler find --scope=site

    echo "Setting binutils_path "
    binutils_path=$(spack find --loaded --long -p | grep binutils | awk '{ print $3 }')/bin
    ${fix_compiler} "$compilers_yaml" gcc@10.2.0 rhel7 x86_64 edit --env="PATH+=${binutils_path}"
    spack unload -a 

elif grep -q 'SLES' /etc/os-release; then
	module switch PrgEnv-"${PE_ENV,,}" PrgEnv-intel

	echo "Checking for compilers under PrgEnv-intel"
	spack compiler find --scope=site

	# Spack finds the intel compilers completely incorrectly.
	IFX=$(which icx)
	ICPX=$(which icpx)

	#Only ever do this once.
	if ! grep 'intel@2021.7.1.classic' "$compilers_yaml"; then
            # The intel compiler is just like the classic one, except different.
        if ! $fix_compiler "$compilers_yaml"  intel@2022.2.1 sles15 x86_64 edit --cc="$IFX" --cxx="$ICPX"; then
            echo "No compiler matching spec intel@2022.2.1 sles15 x86_64"
        fi

    fi

    # The version of oneapi is correct too, so we have to 'fix' it.
    # $fix_compiler "$compilers_yaml"  oneapi@2022.0.0 sles15 x86_64 edit --rename oneapi@2022.0.2


	echo "Checking for compilers under PrgEnv-cray"
	module switch PrgEnv-intel PrgEnv-cray
	spack compiler find --scope=site

	module switch PrgEnv-cray PrgEnv-gnu

	echo "Checking for compilers under PrgEnv-gnu"
	spack compiler find --scope=site

	echo "Explicitly adding GCC 11.2.0"
	module swap gcc gcc/11.2.0
	spack compiler find --scope=site

	if ! spack compiler list | grep 'gcc@11\.2\.0'; then
		echo "Could not find gcc@11.2.0"
		exit 1
	fi
fi

