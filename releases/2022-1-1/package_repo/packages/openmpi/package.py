##############################################################################
# Copyright (c) 2013-2018, Lawrence Livermore National Security, LLC.
# Produced at the Lawrence Livermore National Laboratory.
#
# This file is part of Spack.
# Created by Todd Gamblin, tgamblin@llnl.gov, All rights reserved.
# LLNL-CODE-647188
#
# For details, see https://github.com/spack/spack
# Please also see the NOTICE and LICENSE files for our notice and the LGPL.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License (as
# published by the Free Software Foundation) version 2.1, February 1999.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the IMPLIED WARRANTY OF
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the terms and
# conditions of the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
##############################################################################
#
# This is a template package file for Spack.  We've put "FIXME"
# next to all the things you'll want to change. Once you've handled
# them, you can save this file and test your package like this:
#
#     spack install openmpi
#
# You can edit this file again by typing:
#
#     spack edit openmpi
#
# See the Spack documentation for more information on packaging.
# If you submit this package back to Spack as a pull request,
# please first remove this boilerplate and all FIXME comments.
#
import fnmatch, os, re
from spack import *
from spack.pkg.builtin.openmpi import Openmpi as BuiltinOpenmpi


class Openmpi(BuiltinOpenmpi):
    """TCE-specific modifications to the OpenMPI package."""

    patch('0001-hwloc-squelch-a-knl-MCDRAM-related-warning.patch', when='@2.1.2')
    patch('0001-quick-and-dirty-fix-for-pmix-enable-static-issue.patch', when='@2.1.2')

#    depends_on('binutils')

    variant('cma', default=True, description='Enable CMA data copy speedup.')

#    def setup_build_environment(self, env):
#        super(Openmpi, self).setup_build_environment(env)
#
#        env.set('LD', self.spec['binutils'].prefix.bin.ld)

    def configure_args(self):
        spec = self.spec
        config_args = super(Openmpi, self).configure_args()

        # Disable user configurations
        config_args.append('--disable-per-user-config-files')

        # Add binutils
        #config_args.append('--with-ld={0}'.format(spec['binutils'].prefix.bin.ld))

        # Faster intra-node data copies.
        if spec.satisfies('+cma'):
            if '--without-cma' in config_args:
                config_args.remove('--without-cma')

        # Ensure proper ptmalloc hooks for mpi_leave_pinned.  OpenMPI's
        # configure doesn't describe this well, so we err on the side of being
        # explicit.
        for item in config_args:
            if re.match('.*with-memory-manager.*', item):
                config_args.remove(item)
                break
        config_args.append('--with-memory-manager=linux')

        # Use our own list of mca components to not build.
        for item in config_args:
            if re.match('.*enable-mca-no-build.*', item):
                config_args.remove(item)
                break
        config_args.append('--enable-mca-no-build=crs,filem,pml-v')

        # Ensure that romio natively works with our filesystems, especially
        # lustre.
        for item in config_args:
            if re.match('.*with-io-romio-flags.*', item):
                config_args.remove(item)
                break
        config_args.append('--with-io-romio-flags=--with-file-system=ufs+nfs+lustre')

        # MPI compiler will fail if no underything Fortran compiler is
        # available.
        for item in config_args:
            if re.match('.*mpi-fortran.*', item):
                config_args.remove(item)
                break
        config_args.append('--enable-mpi-fortran')

        return config_args

    # Removing '--enable-new-dtags' flags as well as links pointing to
    # /usr/lib64.
    @run_after('install')
    def modify_options(self):
        kwargs = {'ignore_absent': True, 'backup': False, 'string': True}
        for filename in os.listdir(self.prefix.share.openmpi):
            if fnmatch.fnmatch(filename, '*-wrapper-data.txt'):
                if self.spec.satisfies('@2.1.2:4.0.99'):
                    filter_file(r'-Wl,--enable-new-dtags', r'',
                                join_path(self.prefix.share.openmpi, filename))
                filter_file(r'-L/usr/lib64', r'',
                            join_path(self.prefix.share.openmpi, filename))
                filter_file(r'-Wl,-rpath -Wl,/usr/lib64', r'',
                            join_path(self.prefix.share.openmpi, filename))
        for filename in os.listdir(self.prefix.lib.pkgconfig):
            if fnmatch.fnmatch(filename, '*.pc'):
                if self.spec.satisfies('@2.1.2:4.0.99'):
                    filter_file(r'-Wl,--enable-new-dtags', r'',
                                join_path(self.prefix.lib.pkgconfig, filename))
                filter_file(r'-L/usr/lib64', r'',
                            join_path(self.prefix.lib.pkgconfig, filename))
                filter_file(r'-Wl,-rpath -Wl,/usr/lib64', r'',
                            join_path(self.prefix.lib.pkgconfig, filename))

    # Place the appropriate mca parameters file in the installation prefix.
    @run_after('install')
    def mca_param_file_placement(self):
        if 'fabrics=psm2' in self.spec and \
           'fabrics=psm' in self.spec and \
           'fabrics=verbs' in self.spec:
            fab_name = 'hfi'
        elif 'fabrics=ucx' in self.spec and \
             'fabrics=verbs' in self.spec:
            fab_name = 'mlx'

        file_name = os.path.join(self.package_dir, 'mca_params',
            'ompi{}'.format(self.spec.version.up_to(1)),
            'toss3-{}-optimized.conf'.format(fab_name))

        target = join_path(self.prefix.etc, 'openmpi-mca-params.conf')

        install(file_name, target)
