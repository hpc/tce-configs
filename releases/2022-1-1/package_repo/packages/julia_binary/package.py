# Copyright 2013-2020 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack import *
class JuliaBinary(Package):
    """Prebuilt binary for
       The Julia Language: A fresh approach to technical computing"""

    homepage = "http://julialang.org"
    url      = "https://julialang-s3.julialang.org/bin/linux/x64/1.5/julia-1.5.3-linux-x86_64.tar.gz"

    maintainers = ['dmageeLANL']

    version('1.5.3', sha256='f190c938dd6fed97021953240523c9db448ec0a6760b574afd4e9924ab5615f1')

    def install(self, spec, prefix):
        # Unpack and copy
        install_tree('.', prefix)