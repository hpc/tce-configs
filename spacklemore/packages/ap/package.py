# Copyright 2013-2020 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack import *

class Ap(Package):
    """Prints absolute path to file or directory after expanding all symlinks"""

    homepage = "https://lc.llnl.gov/gitlab/tce/ap"

    git      = "ssh://git@czgitlab.llnl.gov:7999/tce/ap.git"

    maintainers = ['gyllenhaal1']

    version('main', branch='main')
    version('1.0', tag='1.0')

    script_names = [
        'ap',
    ]

    def install(self, spec, prefix):
        mkdirp(prefix.bin)
        for name in self.script_names:
            set_executable(name)
            install(name, prefix.bin)

