# Copyright 2013-2020 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack import *
from spack.pkg.builtin.openblas import Openblas as BuiltinOpenblas


class Openblas(BuiltinOpenblas):
    """TCE-specific modifications for the Openblas package."""

    @property
    def make_defs(self):

        make_defs = super(BuiltinOpenblas, self).make_defs()
        make_defs.append('CXX={0}'.format(spack_cxx))

        return make_defs
