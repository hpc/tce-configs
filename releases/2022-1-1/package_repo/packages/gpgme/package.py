# Copyright 2013-2020 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
from spack import *
from spack.pkg.builtin.gpgme import Gpgme as BuiltinGpgme

import inspect
import os


class Gpgme(BuiltinGpgme):
    """TCE-specific modifications to the gpgme package."""

    # Redirect output to /dev/null as there are characters that Spack's log
    # parsing can't decode.
    def build(self, spec, prefix):
        with working_dir(self.build_directory):
            inspect.getmodule(self).make(*self.build_targets,
                    output=os.devnull)
