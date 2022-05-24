#!/bin/bash

install_dir=$1
compilers_yaml=${install_dir}/spack/etc/spack/compilers.yaml
fix_compiler="${REPO_ROOT}/bin/fix_compiler" # REPO_ROOT provided by wrapper

spack_install="spack ${SPACK_VERBOSE} install ${SPACK_NO_CACHE} --no-checksum"

# gcc@11.3.0
${spack_install} gcc@11.3.0%gcc@10.3.1+binutils+cxa_atexit+nvptx+piclibs+profiledbootstrap-lean+strip languages=c,c++,fortran,lto patches=de02757db510055a149390f95c3e06f62992ff61ff65e74642f8b4d4a4438320 ^binutils@2.36.1+gas+gold~headers~interwork+ld~libiberty~lto~nls+plugins libs=shared,static

spack load gcc@11.3.0
spack compiler find --scope=site 
gfortran_path=$(readlink -f "$(which gfortran)")
gcc_path=$(dirname "$(dirname "$(readlink -f "$(which gcc)")")")
# Set the binutils for this compiler to the one we built. 
spack unload -a 

# intel@2021.2.0
${spack_install} intel-oneapi-compilers@2021.2.0 %gcc@11.3.0
spack load intel-oneapi-compilers
spack compiler find --scope=site
${fix_compiler} "$compilers_yaml" delete oneapi@2021.2.0 rhel8 x86_64
${fix_compiler} "$compilers_yaml" edit intel@2021.2.0 rhel8 x86_64\
    --env="PATH+=${gcc_path}/bin" --env="LD_LIBRARY_PATH+=${gcc_path}/lib64"\
    --env="GCC=${gcc_path}"
spack unload -a

# clang@12.0.0
${spack_install} llvm@12.0.0+all_targets+clang~code_signing+compiler-rt~cuda~flang+gold+internal_unwind~ipo+libcxx+lld+lldb~llvm_dylib~mlir~omp_debug+omp_tsan+polly+python~shared_libs~split_dwarf build_type=Release cuda_arch=none %gcc@11.3.0
spack load llvm@12.0.0
spack compiler find --scope=site
${fix_compiler} "$compilers_yaml" edit clang@12.0.0 rhel8 x86_64\
    --env="PATH+=${gcc_path}/bin"\
    --flags="fflags=-w -fallow-argument-mismatch -O3"\
    --f77="${gfortran_path}" --fc="${gfortran_path}"
spack unload -a

spack load binutils%gcc@11.3.0
binutils_path=$(dirname "$(which ld)")
${fix_compiler} "$compilers_yaml" edit gcc@11.3.0 rhel8 x86_64\
    --env="PATH+=${binutils_path}"
spack unload -a
