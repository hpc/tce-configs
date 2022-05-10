# Copyright 2013-2020 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

import os
import re
from llnl.util.lang import dedupe
from llnl.util.filesystem import path_contains_subdirectory
from llnl.util.link_tree import LinkTree
from spack.util.prefix import Prefix
from spack.spec import CompilerSpec


class TceCompilerWrappers(Package):
    """ These are the small TCE wrappers generated per-compiler

    These are called by the smaller mpi and compiler wrappers
    As a matter of policy, we will install these "with only one compiler"
    until Spack allows us to install without associating a compiler."""

    # Spack appears to want patchelf in the path no matter what, so
    # put a already build version in the path since
    # cce@12.0.0 cannot build patchelf due to missing -lgcc_s
    depends_on('patchelf@0.12%gcc@10.2.1')

    homepage = "https://lc.llnl.gov/gitlab/tce/tce-compiler-wrappers"
    git      = "ssh://git@czgitlab.llnl.gov:7999/tce/tce-compiler-wrappers.git"

    maintainers = ['gyllenhaal1']

    version('main', branch='main')
    version('3.0', tag='3.0')
    version('2.0', tag='2.0')
    version('1.0', tag='1.0')

    # These packages fake a dependency on tce-wrapper-drivers via the view
    # depends_on('tce-wrapper-drivers%gcc@10.2.1', type='run')
    # depends_on('tce-wrapper-drivers@main', type='run', when='@main')

    # Associate cray wrappers with rocm versions
    # depends_on('rocm', when='%cce', type='run')
    # depends_on('rocm@4.0.1', when='%cce@11.0.3:11.0.4', type='run')

    # nested dict compiler_name -> language -> filenames
    # TODO: complete this list
    script_names = {
        'gcc': {
            'C': ['gcc'],
            'C++': ['g++'],
            'FORTRAN': ['gfortran'],
        },
        'clang': {
            'C': ['clang'],
            'C++': ['clang++'],
            'FORTRAN': ['flang'],
        },
        'intel': {
            'C': ['icc'],
            'C++': ['icpc'],
            'FORTRAN': ['ifort'],
        },
        'oneapi': {
            'C': ['icx'],
            'C++': ['icpx'],
            'FORTRAN': ['ifx'],
        },
        'cce': {
            'C': ['craycc'],
            'C++': ['crayCC'],
            'FORTRAN': ['crayftn'],
        },
        'aocc': {
            'C': ['amdclang'],
            'C++': ['amdclang++', 'hipcc'],
            'FORTRAN': ['amdflang'],
        }
    }

    # Cray fortran in 11.0.4 had different path than C++,
    # so map language to tags in craype-stack to get paths in cce
    compiler_attrs = {
        'C': 'cc',
        'C++': 'cxx',
        'FORTRAN': 'fc',
        'HIP': 'cxx',
    }


    # This is the filename in the git repo
    basename = 'base-compiler-wrapper'

    def install(self, spec, prefix):
        # Symlink everything from the compiler in
        # Symlink directories at the top level, except for bin
        mkdirp(prefix.bin)
        compiler_prefix = Prefix(
            os.path.dirname(os.path.dirname(self.compiler.cc)))
        for entry in os.listdir(compiler_prefix):
            if entry != 'bin' and entry != 'var' and not entry.startswith('.'):  # gcc fails for var, weird errors if copy .spack
                src = compiler_prefix.join(entry)
                if os.path.isdir(src) and os.access(src, os.X_OK):
                    link_tree = LinkTree(src)
                    link_tree.merge(prefix.join(entry))
                else:
                    os.symlink(src, prefix.join(entry))

        script_names = self.script_names[self.compiler.name]

        for lang, names in script_names.items():
            active_compiler_spec = spec.compiler
            for script in names:
                compiler_attr = self.compiler_attrs[lang]
                compiler_path = getattr(self.compiler, compiler_attr)
                compiler_name = os.path.basename(compiler_path)
                # Handle case where using crayftn instead of amdflang
                if script != compiler_name:
                    if script in ['amdflang'] and compiler_name in ['crayftn']:
                        script=compiler_name

                copy(self.basename, script)
                compiler_version=str(active_compiler_spec.version)
                cmp_prefix = Prefix(
                    os.path.dirname(os.path.dirname(getattr(self.compiler, compiler_attr))))
                if active_compiler_spec.satisfies('aocc'):
                    # Detect if have extra .9 added to rocm version to indicate use cce used for fortran
                    if compiler_version.count('.') == 3 and compiler_version.endswith(".9"):
                        if lang == 'FORTRAN':
                            filter_file(r'COMPILER_FAMILY=.*', 'COMPILER_FAMILY=%s' % 'cce', script)
                            # Get the compiler version from the cce path to the fortran compiler
                            filter_file(r'COMPILER_VERSION=.*', 'COMPILER_VERSION=%s' % cmp_prefix.split("/")[-1], script)
                        else:
                            # Need to remove extra .9 for C/C++ compiler version
                            filter_file(r'COMPILER_FAMILY=.*', 'COMPILER_FAMILY=%s' % 'rocmcc', script)
                            filter_file(r'COMPILER_VERSION=.*', 'COMPILER_VERSION=%s' % compiler_version[:-2], script)
                    # We currently have to add .0 to other versions (i.e., 4.3.0.0) to prevent substring matching errors for version
                    elif compiler_version.count('.') == 3:
                        filter_file(r'COMPILER_FAMILY=.*', 'COMPILER_FAMILY=%s' % 'rocmcc', script)
                        filter_file(r'COMPILER_VERSION=.*', 'COMPILER_VERSION=%s' % compiler_version[:-2], script)
                    # This cannot be used while we are creating 4.3.0.9 for mixed version, must use 4.3.0.0 for pure version
                    else:
                        filter_file(r'COMPILER_FAMILY=.*', 'COMPILER_FAMILY=%s' % 'rocmcc', script)
                        filter_file(r'COMPILER_VERSION=.*', 'COMPILER_VERSION=%s' % compiler_version, script)
                else:
                    filter_file(r'COMPILER_FAMILY=.*', 'COMPILER_FAMILY=%s' % active_compiler_spec.name, script)
                    filter_file(r'COMPILER_VERSION=.*', 'COMPILER_VERSION=%s' % compiler_version, script)
                filter_file(r'COMPILER_DIR=.*', 'COMPILER_DIR=%s' % cmp_prefix, script)

                if active_compiler_spec.satisfies('cce'):
                    rocm_path=os.getenv('TCE_ROCM_PATH', default='TCE_ROCM_PATH NOT SET IN spack.yaml')
                    filter_file(r'COMPILER_LANGUAGE=.*', 'COMPILER_LANGUAGE=%s\nexport COMPILER_ROCM_PATH=%s' % (lang, rocm_path), script)

                elif active_compiler_spec.satisfies('aocc'):
                    # Detect if have extra .9 added to rocm version to indicate use cce used for fortran
                    if compiler_version.count('.') == 3 and compiler_version.endswith(".9"):
                        rocm_version=str(spec.compiler.version)[:-2]
                    # We currently have to add .0 to other versions (4.3.0.0) to prevent substring matching errors for version
                    elif compiler_version.count('.') == 3:
                        rocm_version=str(spec.compiler.version)[:-2]
                    # This cannot be used while we are creating 4.3.0.9 for mixed version, must use 4.3.0.0 for pure version
                    else: 
                        rocm_version=str(spec.compiler.version)
                    if script.endswith("hipcc"):
                        filter_file(r'COMPILER_LANGUAGE=.*', 'COMPILER_LANGUAGE=%s\nexport COMPILER_ROCM_PATH=/opt/rocm-%s' % ('HIP', rocm_version), script)
                    else:
                        filter_file(r'COMPILER_LANGUAGE=.*', 'COMPILER_LANGUAGE=%s\nexport COMPILER_ROCM_PATH=/opt/rocm-%s' % (lang, rocm_version), script)
                else:
                    filter_file(r'COMPILER_LANGUAGE=.*', 'COMPILER_LANGUAGE=%s' % lang, script)

                set_executable(script)
                if os.path.exists(prefix.bin.join(script)):
                    os.unlink(prefix.bin.join(script))
                install(script, prefix.bin)

    def add_files_to_view(self, view, merge_map):
        bin_dir = self.spec.prefix.bin
        family_reg_exp = re.compile(r'COMPILER_FAMILY=(\S+)')
        for src, dst in merge_map.items():
            if not path_contains_subdirectory(src, bin_dir):
                view.link(src, dst, spec=self.spec)
                continue

            # We've already bailed out if we don't need this
            copy(src, dst)
            locator_spec = Spec('tce-wrapper-drivers')

            with open(src, 'r') as f:
                content = f.read()
            for lang, attr in self.compiler_attrs.items():
                if 'COMPILER_LANGUAGE=%s' % lang in content:
                    compiler_path = getattr(self.compiler, attr)
                    if lang == 'HIP':
                         compiler_dir=os.path.dirname(compiler_path)
                         # For 4.2.0 and earlier, need to remove /llvm from path
                         compiler_dir=compiler_dir.replace('/llvm/bin','/bin')
                         compiler_path=os.path.join(compiler_dir, "hipcc")
                    #    compiler_path=os.getenv('HIPCC_PATH', default='HIPCC_PATH NOT SET IN spack.yaml')
                    #else: 
                    #    compiler_path = getattr(self.compiler, attr)
            match = re.search(family_reg_exp, content)
            if match:
                wrapper_name = match.group(1) + '-wrapper'
            else:
                raise RuntimeError("Could not find COMPILER_FAMILY= during view fixup of %s" % src)
            view_path = get_view_path_for_spec(locator_spec, view)
            wrapper_path = os.path.join(view_path,  wrapper_name)
            filter_file('exec.*', 'exec %s %s "$@"' % (wrapper_path, compiler_path), dst, backup=False)

def get_view_path_for_spec(spec, view):
    view_path = os.path.join(view.get_projection_for_spec(spec), 'bin')
    real_dirname, real_basename = os.path.split(os.path.dirname(view._root))
    real_basename = real_basename[2:]
    return view_path.replace(view._root, os.path.join(real_dirname, real_basename), 1)
