# Copyright 2013-2019 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack import *
from spack.pkg.builtin.subversion import Subversion as BuiltinSubversion


class Subversion(BuiltinSubversion):
    """TCE-specific modifications for the subversion package."""

    variant('apxs', default=True, description='Build with APXS')
    variant('lz4_internal', default=False, description='Build with internal lz4')
    variant('utf8proc_internal', default=False, description='Build with internal utf8proc')

    def configure_args(self):
        args = super(Subversion, self).configure_args()
        spec = self.spec
        if spec.satisfies('+perl'):
            args.append('PERL=%s' % spec['perl'].command.path)
        if spec.satisfies('+lz4_internal'):
            args.append('--with-lz4=internal')
        if spec.satisfies('+utf8proc_internal'):
            args.append('--with-utf8proc=internal')
        if spec.satisfies('~apxs'):
            args.append('APXS=no')

        return args
