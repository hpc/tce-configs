# Copyright 2013-2020 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
from datetime import datetime
import os

class TceUtilsDefaults(Package):
    """This package creates a link tree of defaults for /usr/tce/bin

    In this package we handle utilities. Toolchain components (compilers/mpis)
    are outside the scope of this package."""
    has_code = False
    
    version('1.0')

    exes = ['git', 'gitk', 'xsu', 'cmake', 'ccmake', 'patchelf', 'ap', 'cloc', 'setup-ssh-keys']
    lmod_config = spack.config.get('modules:utils:lmod', {})
    defaults = lmod_config.get('defaults', [])

    defaults = ['git@2.29.1+tcltk', 'cmake@3.14.5+ownlibs', 'patchelf@0.10',
                'setup-ssh-keys@1.0', 'xsu@1.0', 'ap@1.0', 'cloc@1.84']  # hardcode until module defaults work

    for spec in defaults:
        depends_on(spec, type='run')

    def install(self, spec, prefix):
        mkdirp(prefix.bin)
        for dep in self.defaults:
            dep = Spec(dep)
            for exe in self.exes:
                src = spec[dep.name].prefix.bin.join(exe)
                if os.path.exists(src):
                    dst = prefix.bin.join(exe)
                    os.symlink(src, dst)

    def add_files_to_view(self, view, merge_map):
        # This looks really ugly
        # What it actually does is ignore the merge_map and reproduce it
        # while using the specs to get the pretty-view for the sources
        # and the view implementation for the deps
        for dep in self.defaults:
            dep = Spec(dep)
            for exe in self.exes:
               # Check that this executable is owned by this dep
                _src_impl = self.spec[dep.name].prefix.bin.join(exe)
                if os.path.exists(_src_impl):
                    src = os.path.join(
                        get_view_path_for_spec(self.spec[dep.name], view),
                        'bin', exe)
                    dst = os.path.join(
                        view.get_projection_for_spec(self.spec),
                        'bin', exe)
                    view.link(src, dst, spec=self.spec)


def get_view_path_for_spec(spec, view):
    view_path = view.get_projection_for_spec(spec)
    real_dirname, real_basename = os.path.split(os.path.dirname(view._root))
    real_basename = real_basename[2:]
    return view_path.replace(view._root, os.path.join(real_dirname, real_basename), 1)
