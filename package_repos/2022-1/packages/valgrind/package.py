# Copyright 2013-2019 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

import sys
from spack import *
from spack.pkg.builtin.valgrind import Valgrind as BuiltinValgrind


class Valgrind(BuiltinValgrind):
    """TCE-specific modifications to the valgrind package."""
    variant('lto', default=False,
            description='Activates link-time optimization for valgrind')

    conflicts('+lto', when='@:3.14', msg='Link-time Optimization only supported in 3.15.0 and above')

    def configure_args(self):
        options = super(Valgrind, self).configure_args()
        spec = self.spec

        if self.spec.platform == 'cray':
            env['SPACK_CC'] = "/opt/gcc/9.3.0/bin/gcc"

        if spec.satisfies('+lto'):
            options.append('--enable-lto')

        if spec.satisfies('+mpi'):
            if self.spec.platform != 'cray':
                options.append('--with-mpicc={0}'.format(self.spec['mpi'].mpicc))
            else:
                options.append("--with-mpicc=env['CC']")

        if sys.platform == 'darwin':
            options.append('--build=amd64-darwin')
        return options
