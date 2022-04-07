# Copyright 2013-2021 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack.pkg.builtin.openssl import Openssl as BuiltinOpenssl

class Openssl(BuiltinOpenssl):
    """TCE-specific openssl package."""

    # somewhat dummy version string to track using openssl provided by SUSE
    # in SLES 15 (taken from SLES 15 Service Pack 2 (15.2))
    version('1.1.1d-sles15')
    # somewhat dummy version string to track using openssl provided by RedHat
    # in RHEL 7 (taken from RHEL 7.9)
    version('1.0.2k-rhel7')
