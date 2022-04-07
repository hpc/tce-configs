# Copyright 2013-2020 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
from spack import *
from spack.pkg.builtin.gtk_doc import GtkDoc as BuiltinGtkDoc


class GtkDoc(BuiltinGtkDoc):
    """TCE-specific modifications to the gtk-doc package.

    Only fix is to make pkgconfig a runtime dependency as well as
    build-time."""

    depends_on('pkgconfig', type=('build', 'run'))
    depends_on('itstool', type='build')
