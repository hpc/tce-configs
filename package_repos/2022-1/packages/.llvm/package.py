# Copyright 2013-2019 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

import os
from spack import *
from spack.pkg.builtin.llvm import Llvm as BuiltinLlvm


class Llvm(BuiltinLlvm):
    """TCE-specific modifications to the llvm package."""

    @run_after('install')
    def post_install(self):
        if '+clang' in self.spec and '+python' in self.spec:
            install_tree(
                'clang/bindings/python/clang',
                join_path(site_packages_dir, 'clang'))

        with working_dir(self.build_directory):
            if not os.path.exists(join_path(self.prefix, 'libexec', 'llvm')):
                install_tree('bin', join_path(self.prefix, 'libexec', 'llvm'))
