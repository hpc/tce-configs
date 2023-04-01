# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack import *
from spack.pkg.builtin.itstool import Itstool as BuiltinItstool


class Itstool(BuiltinItstool):
    """TCE-specific itstool package."""

    version('2.0.7', sha256='6b9a7cd29a12bb95598f5750e8763cee78836a1a207f85b74d8b3275b27e87ca')

    conflicts('^python3', when='@:2.0.2')
