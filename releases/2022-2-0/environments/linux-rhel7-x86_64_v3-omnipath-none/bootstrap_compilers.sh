#!/bin/bash
if [[ -z "${SPACK_CACHING}" ]] ; then echo "SPACK_CACHING isn't defined, bailing!" ; exit 1; fi
install_dir="$1"
compilers_yaml="${install_dir}/spack/etc/spack/compilers.yaml"
fix_compiler="${REPO_ROOT}/bin/fix_compiler" # REPO_ROOT provided by wrapper

spack_install="spack ${SPACK_VERBOSE} install ${SPACK_CACHING} --no-checksum"

# gcc@11.3.0
${spack_install} gcc@11.3.0%gcc@4.8.5+binutils+nvptx+piclibs+strip languages=c,c++,fortran,lto patches=de02757db510055a149390f95c3e06f62992ff61ff65e74642f8b4d4a4438320 ^binutils@2.36.1+gas+gold~headers~interwork+ld~libiberty~lto~nls+plugins libs=shared,static

spack load gcc@11.3.0
spack compiler find --scope=site
gfortran_path="$(which gfortran)"
gcc_path="$(dirname "$(dirname "$(readlink -f "$(which gcc)")")")"
# Set the binutils for this compiler to the one we built.
${spack_install} binutils@2.36.1+gas+gold~headers~interwork+ld~libiberty~lto~nls+plugins libs=shared,static %gcc@11.3.0
spack load binutils@2.36.1+gas+gold~headers~interwork+ld~libiberty~lto~nls+plugins libs=shared,static %gcc@11.3.0
binutils_path="$(dirname "$(which ld)")"
${fix_compiler} "$compilers_yaml" edit gcc@11.3.0 rhel7 x86_64\
    --env="PATH+=${binutils_path}"
spack unload -a

# gcc@9.3.0
${spack_install} gcc@9.3.0%gcc@4.8.5+binutils+nvptx+piclibs+strip languages=c,c++,fortran,lto patches=de02757db510055a149390f95c3e06f62992ff61ff65e74642f8b4d4a4438320 ^binutils@2.36.1+gas+gold~headers~interwork+ld~libiberty~lto~nls+plugins libs=shared,static

spack load gcc@9.3.0
spack compiler find --scope=site
gfortran_path="$(which gfortran)"
gcc_path="$(dirname "$(dirname "$(readlink -f "$(which gcc)")")")"
# Set the binutils for this compiler to the one we built.
${spack_install} binutils@2.36.1+gas+gold~headers~interwork+ld~libiberty~lto~nls+plugins libs=shared,static %gcc@9.3.0
spack load binutils@2.36.1+gas+gold~headers~interwork+ld~libiberty~lto~nls+plugins libs=shared,static %gcc@9.3.0
binutils_path="$(dirname "$(which ld)")"
${fix_compiler} "$compilers_yaml" edit gcc@9.3.0 rhel7 x86_64\
    --env="PATH+=${binutils_path}"
spack unload -a

# intel@2021.2.0
${spack_install} intel-oneapi-compilers@2021.2.0 %gcc@11.3.0
spack load intel-oneapi-compilers
spack compiler find --scope=site
${fix_compiler} "$compilers_yaml" delete oneapi@2021.2.0 rhel7 x86_64
${fix_compiler} "$compilers_yaml" edit intel@2021.2.0 rhel7 x86_64\
    --env="PATH+=${gcc_path}/bin" --env="LD_LIBRARY_PATH+=${gcc_path}/lib64"\
    --env="GCC=${gcc_path}"
spack unload -a

# clang@12.0.0
${spack_install} llvm@13.0.1 targets=all +clang~code_signing+compiler-rt~cuda~flang+gold+internal_unwind~ipo+libcxx+lld+lldb~llvm_dylib~mlir~omp_debug+omp_tsan+polly+python~shared_libs~split_dwarf build_type=Release  %gcc@11.3.0 ^libxml2@2.9.13%gcc@11.3.0+python
spack load llvm@13.0.1
spack compiler find --scope=site
${fix_compiler} "$compilers_yaml" edit clang@13.0.1 rhel7 x86_64\
    --env="PATH+=${gcc_path}/bin"\
    --env="PATH+=${binutils_path}"\
    --f77="${gfortran_path}" --fc="${gfortran_path}"\
    --flags="fflags=-w -fallow-argument-mismatch -O3"
spack unload -a
