# Copyright 2013-2020 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack import *
from spack.pkg.builtin.flux_core import FluxCore as BuiltinFluxCore


class FluxCore(BuiltinFluxCore):
    """TCE-specific modifications to the flux-core package."""

    def setup_build_environment(self, env):
        super(FluxCore, self).setup_build_environment(env)
        env.set('LUA', self.spec['lua'].prefix.bin.lua)
        env.set('LUA_INCLUDE', self.spec['lua'].prefix.include)
        env.set('LUA_LIB', '-llua5.2')

    def configure_args(self):
        args = super(FluxCore, self).configure_args()
        args.append('ax_cv_lua_header_version={}'.format(str(self.lua_version)))
        args.append('ax_cv_search_lua_load=-llua')
        return args
