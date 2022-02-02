# Copyright 2013-2020 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

import os
from spack import *
from spack.pkg.builtin.lua import Lua as BuiltinLua


class Lua(BuiltinLua):
    """TCE-specific modifications to the lua package."""

    def static_to_shared_library(self, path, args, ver,
            compver):
        """Override this function just to add a single argument."""
        args.append('-nostartfiles')
        super(Lua, self).static_to_shared_library(path, arguments=args,
                                                      version=ver,
                                                      compat_version=compver)
