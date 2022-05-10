# Copyright 2013-2020 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

import sys
from spack import *
from spack.pkg.builtin.git import Git as BuiltinGit

class Git(BuiltinGit):
    """TCE-specific modifications to the git package."""

    variant('subtree', default=True,
            description='Add git-subtree command and capability')

    def configure_args(self):
        args = super(Git, self).configure_args()
        args.append('--with-lib=lib64')
        return args

    @run_after('install')
    def install_subtree(self):
        if '+subtree' in self.spec:
            with working_dir('contrib/subtree'):
                make_args = ['V=1', 'prefix={}'.format(self.prefix)]
                make(" ".join(make_args))
                install_args = ['V=1', 'prefix={}'.format(self.prefix), 'install']
                make(" ".join(install_args))
                install('git-subtree', self.prefix)
