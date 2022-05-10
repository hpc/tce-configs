# Copyright 2013-2020 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)
import os

class TceWrapperDrivers(Package):
    """
    These are the full templated wrappers

    These are called by the smaller mpi and compiler wrappers
    As a matter of policy, we will install these "with only one compiler"
    until Spack allows us to install without associating a compiler."""
 
    # Spack requiring patchelf, so require same one as built already!
    # Believe no longer necessary, and should be 8.3.1, try commenting out -JCG 2/7/22
    # depends_on('patchelf@0.12%gcc@10.2.1')

    homepage = "https://lc.llnl.gov/gitlab/tce/tce-wrapper-drivers"
    git      = "ssh://git@czgitlab.llnl.gov:7999/tce/tce-wrapper-drivers.git"

    maintainers = ['gyllenhaal1']

    version('main', branch='main')
    version('19.0', tag='19.0')
    version('18.0', tag='18.0')
    version('17.0', tag='17.0')
    version('16.0', tag='16.0')
    version('15.0', tag='15.0')
    version('14.0', tag='14.0')
    version('13.0', tag='13.0')
    version('12.0', tag='12.0')
    version('11.0', tag='11.0')
    version('10.0', tag='10.0')
    version('9.0', tag='9.0')
    version('8.0', tag='8.0')
    version('7.0', tag='7.0')
    version('6.0', tag='6.0')
    version('5.0', tag='5.0')
    version('4.0', tag='4.0')
    version('3.0', tag='3.0')
    version('2.0', tag='2.0')
    version('1.0', tag='1.0')

    link_files = {
        'gcc-10': [
            '/usr/lib64/libgfortran.so.5',
            '/usr/lib64/libgcc_s.so.1',
            '/usr/lib64/libstdc++.so.6',
        ],
    }

    def install(self, spec, prefix):
        mkdirp(prefix.bin)
        for name in os.listdir():
            if not name.startswith('.'):
                set_executable(name)
                install(name, prefix.bin)

        for name, libs in self.link_files.items():
            dirname = prefix.join(name).join('lib64')
            mkdirp(dirname)
            for lib in libs:
                name = os.path.basename(lib)
                os.symlink(lib, dirname.join(name))
