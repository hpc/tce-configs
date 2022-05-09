# Copyright 2013-2020 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
import os
from llnl.util.lang import dedupe
from llnl.util.filesystem import path_contains_subdirectory
from llnl.util.link_tree import LinkTree


class TceMpiWrappers(Package):
    """
    These are the small TCE wrappers generated per-compiler/per-mpi
    """

    # Spack MPI support wants patchelf in the path no matter what, so
    # put a already build version in the path since 
    # cce@12.0.0 cannot build patchelf due to missing -lgcc_s
    depends_on('patchelf@0.12%gcc@10.2.1')

    homepage = "https://lc.llnl.gov/gitlab/tce/tce-mpi-wrappers"
    git      = "ssh://git@czgitlab.llnl.gov:7999/tce/tce-mpi-wrappers.git"

    maintainers = ['gyllenhaal1']

    version('main', branch='main')
    version('5.0', tag='5.0')  # Same as 4.0 but to force libfabric/1.7.2-llnl rename rollout
    version('4.0', tag='4.0')
    version('3.0', tag='3.0')
    version('2.0', tag='2.0')
    version('1.0', tag='1.0')

    # tce-mpi-wrappers fakes its dependencies on other tce wrappers through the view
    # depends_on('tce-wrapper-drivers%gcc@10.2.1', type='run')
    # depends_on('tce-wrapper-drivers@main', type='run', when='@main')
    # depends_on('tce-compiler-wrappers', type='run')
    # depends_on('tce-compiler-wrappers@main', type='run', when='@main')
    depends_on('mpi', type='run')
    # nested dict compiler_name -> language -> filenames
    # TODO: complete this list
    script_names = {
        'gcc': {
            'C': [('mpigcc', 'gcc'), ('mpicc', 'gcc')],
            'C++': [('mpig++', 'g++'), ('mpic++', 'g++'), ('mpicxx', 'g++')],
            'FORTRAN': [('mpigfortran', 'gfortran'), ('mpifc', 'gfortran'), ('mpif77', 'gfortran'), ('mpifort', 'gfortran')],
        },
        'clang': {
            'C': [('mpiclang', 'clang'), ('mpicc', 'clang')],
            'C++': [('mpiclang++', 'clang++'), ('mpic++', 'clang++'), ('mpicxx', 'clang++')],
            'FORTRAN': [('mpiflang', 'flang'), ('mpifc', 'flang'), ('mpif77', 'flang'), ('mpif90', 'flang'), ('mpifort', 'flang')],
        },
        'intel': {
            'C': [('mpiicc', 'icc'), ('mpicc', 'icc')],
            'C++': [('mpiicpc', 'icpc'), ('mpic++', 'icpc'), ('mpicxx', 'icpc')],
            'FORTRAN': [('mpiifort', 'ifort'), ('mpifc', 'ifort'), ('mpif77', 'ifort'), ('mpif90', 'ifort'), ('mpifort', 'ifort')],
        },
        'oneapi': {
            'C': [('mpiicx', 'icx'), ('mpicc', 'icx')],
            'C++': [('mpiicpx', 'icpx'), ('mpic++', 'icpx'), ('mpicxx', 'icpx')],
            'FORTRAN': [('mpiifx', 'ifx'), ('mpifc', 'ifx'), ('mpif77', 'ifx'), ('mpif90', 'ifx'), ('mpifort', 'ifx')],
        },
        'cce': {
            'C': [('mpicraycc', 'craycc'), ('mpicc', 'craycc')],
            'C++': [('mpicrayCC', 'crayCC'), ('mpic++', 'crayCC'), ('mpicxx', 'crayCC')],
            'FORTRAN': [('mpicrayftn', 'crayftn'), ('mpifc', 'crayftn'), ('mpif77', 'crayftn'), ('mpif90', 'crayftn'), ('mpifort', 'crayftn')],
        },
        'aocc': {
            'C': [('mpiamdclang', 'amdclang'), ('mpicc', 'amdclang')],
            'C++': [('mpiamdclang++', 'amdclang++'), ('mpic++', 'amdclang++'), ('mpicxx', 'amdclang++')],
            'HIP': [('mpihipcc', 'hipcc')],
            'FORTRAN': [('mpiamdflang', 'amdflang'), ('mpifc', 'amdflang'), ('mpif77', 'amdflang'), ('mpif90', 'amdflang'), ('mpifort', 'amdflang')],
        },
        'rocmcc': {
            'C': [('mpiamdclang', 'amdclang'), ('mpicc', 'amdclang')],
            'C++': [('mpiamdclang++', 'amdclang++'), ('mpic++', 'amdclang++'), ('mpicxx', 'amdclang++')],
            'HIP': [('mpihipcc', 'hipcc')],
            'FORTRAN': [('mpiamdflang', 'amdflang'), ('mpifc', 'amdflang'), ('mpif77', 'amdflang'), ('mpif90', 'amdflang'), ('mpifort', 'amdflang')],
        },
    }

    # This is the filename in the git repo
    basename = 'base-mpi-wrapper'

    def install(self, spec, prefix):
        mkdirp(prefix.bin)
        for entry in os.listdir(spec['mpi'].prefix):
            if entry != 'bin' and not entry.startswith('.'):
                src = spec['mpi'].prefix.join(entry)
                if os.path.isdir(src):
                    link_tree = LinkTree(src)
                    link_tree.merge(prefix.join(entry))
                else:
                    os.symlink(src, prefix.join(entry))

        script_names = self.script_names[self.compiler.name]

        mpi_add_for_link = None
        if spec['mpi'].name == 'cray-mpich':
            mpi_add_for_link = spec['mpi'].extra_attributes['mpi_add_for_link']

        for lang, names in script_names.items():
            for script, compiler_name in names:
                compiler_version = str(self.compiler.version)
                compiler_family = str(self.compiler.name)
                compiler_dir = str(os.path.dirname(os.path.dirname(self.compiler.cc)))
                # Handle extra version character and possible mpicrayftn name with aocc
                if self.compiler.name == 'aocc':
                    # aocc requires extra .0 or .9 on version to indicate whether crayftn or amdflang used
                    if compiler_version.count('.') == 3:
                        if script == 'mpiamdflang'and compiler_version.endswith(".9"):
                            script = 'mpicrayftn'
                        if lang == 'FORTRAN' and compiler_version.endswith(".9"):
                            compiler_family = "cce"
                        # Remove trailing signaling .0 or .9, fortran fixed up during view creation
                        compiler_version=compiler_version[:-2]
                        
                copy(self.basename, script)
                filter_file(r'COMPILER_VERSION=.*', 'COMPILER_VERSION=%s' % compiler_version, script)
                filter_file(r'COMPILER_FAMILY=.*', 'COMPILER_FAMILY=%s' % compiler_family, script)
                filter_file(r'COMPILER_DIR=.*', 'COMPILER_DIR=%s' % compiler_dir, script)
                filter_file(r'COMPILER_LANGUAGE=.*', 'COMPILER_LANGUAGE=%s' % lang, script)
                filter_file(r'MPI_FAMILY=.*', 'MPI_FAMILY=%s' % spec['mpi'].name, script)
                filter_file(r'MPI_VERSION=.*', 'MPI_VERSION=%s' % spec['mpi'].version, script)
                filter_file(r'MPI_DIR=.*', 'MPI_DIR=%s' % spec['mpi'].prefix, script)

                if mpi_add_for_link:
                    filter_file(r'MPI_ADD_FOR_LINK=.*', 'MPI_ADD_FOR_LINK=%s' % mpi_add_for_link, script)

                set_executable(script)
                install(script, prefix.bin)

    def add_files_to_view(self, view, merge_map):
        bin_dir = self.spec.prefix.bin
        for src, dst in merge_map.items():
            if not path_contains_subdirectory(src, bin_dir):
                view.link(src, dst, spec=self.spec)
                continue

            # We've already bailed out if we don't need this
            # everything in bin is already our wrappers
            copy(src, dst)
            driver_locator_spec = Spec('tce-wrapper-drivers')
            driver_view_prefix = get_view_path_for_spec(driver_locator_spec, view)
            driver_view_path = os.path.join(driver_view_prefix, 'bin')
            driver_wrapper_name = self.spec['mpi'].name + '-wrapper'
            driver_wrapper_path = os.path.join(driver_view_path,  driver_wrapper_name)

            compiler_locator_spec = Spec('tce-compiler-wrappers%{0}'.format(self.spec.compiler))
            compiler_view_prefix = get_view_path_for_spec(compiler_locator_spec, view)
            compiler_view_path = os.path.join(compiler_view_prefix, 'bin')
            current_name = os.path.basename(src)
            compiler_version=str(self.compiler.version)
            for lang, scripts in self.script_names[self.compiler.name].items():
                for mpi_compiler, compiler in scripts:
                    # Rename mpiamdflang to mpicrayftn for test below if needed
                    if mpi_compiler == 'mpiamdflang' and compiler_version.count('.') == 3 and compiler_version.endswith(".9"):
                       mpi_compiler = 'mpicrayftn'
                    if current_name == mpi_compiler:
                        compiler_name = compiler
                        break

            # For aocc compilers ending in .9, use crayftn instead of amdflang
            if compiler_name == 'amdflang' and compiler_version.count('.') == 3 and compiler_version.endswith(".9"):
               compiler_name = 'crayftn'
               # assume view prefix is of the form .../packages/rocmcc-cce-tce/rocmcc-4.3.0-cce-12.0.2 to enable getting 12.0.2
               filter_file(r'COMPILER_VERSION=.*', 'COMPILER_VERSION=%s' % compiler_view_prefix.split("-")[-1], dst, backup=False)

            filter_file(r'COMPILER_DIR=.*', 'COMPILER_DIR=%s' % compiler_view_prefix, dst, backup=False)
            compiler_wrapper_path = os.path.join(compiler_view_path, compiler_name)
            filter_file(r'exec.*', 'exec %s %s "$@"' % (driver_wrapper_path, compiler_wrapper_path), dst, backup=False)

            if not self.spec['mpi'].external:
                mpi_view_path = get_view_path_for_spec(self.spec['mpi'], view)
                filter_file(self.spec['mpi'].prefix, mpi_view_path, dst, backup=False)

def get_view_path_for_spec(spec, view):
    view_path = view.get_projection_for_spec(spec)
    real_dirname, real_basename = os.path.split(os.path.dirname(view._root))
    real_basename = real_basename[2:]
    return view_path.replace(view._root, os.path.join(real_dirname, real_basename), 1)
