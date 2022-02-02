# Copyright 2013-2019 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack import *

import os


class Totalview(Package):
    """Totalview parallel debugger."""

    homepage = "https://www.roguewave.com/products-services/totalview"
    url = "totalview.2019.2.18-doc.tar"
    license_required = True
    license_vars = ['TV_LICENSE_FILE']

    # As the install of Totalview is via multiple tarballs, the base install
    # will be the documentation.  The architecture-specific tarballs are added
    # as resources dependent on the specific architecture used.
    version('2019.2.18',
            sha256='09e5c554032af945f8cf147dd548421267e50e906cc9686fb5cd0e8e63fcf650')
    version('2021.1.16',
            sha256='4c51c7b6ab6b6afa7635ba2e9fc3b0ef833806f775a0ad0da26b13d6320625dd')

    # Distributed with Totalview
    variant('memoryscape', default=True, description='Install memoryscape')
        # Clearly, there are other tarballs for power and x86, but I don't have
        # those files to definitely determine the appropriate filenames and
        # hashes.

    resource(
            name='x86_64',
            url='totalview_{0}_linux_x86-64.tar'.format(version),
            destination='.',
            sha256='3b0ab078deff3654ddc912a004d256f1376978aa1c4dd5a8a41fa9fbb474d07c',
            when='@2019.2.18 target=x86_64:'
            )
    resource(
            name='aarch64',
            url='totalview_{0}_linux_arm64.tar'.format(version),
            destination='.',
            sha256='3bbda1aa7c06ce82874c1517bf949c9f6cbd0f4c9ebe283d21f0643f6e724b6b',
            when='@2019.2.18 target=aarch64:'
            )
    resource(
            name='ppcle',
            url='totalview_{0}_linux_powerle.tar'.format(version),
            destination='.',
            sha256='c0e4dbf145312fc7143ad0b7e9474e653933581990e0b9d07237c73dbdff8365',
            when='@2019.2.18 target=ppcle:'
            )

    resource(
            name='x86_64',
            url='totalview_{0}_linux_x86-64.tar'.format(version),
            destination='.',
            sha256='129e991d3ce4df9f9f04adbf79b62d3c2706d7732ec305f3d3c97a6b4d1f5a13',
            when='@2021.1.16 target=x86_64:'
            )
    resource(
            name='aarch64',
            url='totalview_{0}_linux_arm64.tar'.format(version),
            destination='.',
            sha256='d559c0e090b2a6b935986324a2f1b20c02c5a2991432b8305952c120db41cdb5',
            when='@2021.1.16 target=aarch64:'
            )
    resource(
            name='ppcle',
            url='totalview_{0}_linux_powerle.tar'.format(version),
            destination='.',
            sha256='88c6bf82bd0807f826e2920967b288ac40e9bc56554e55966dfea793bc9c2b0a',
            when='@2021.1.16 target=ppcle:'
            )

    def setup_run_environment(self, env):
        env.prepend_path('PATH',
                         join_path(self.prefix, 'toolworks',
                                   'totalview.{}'.format(self.version), 'bin'))
        env.prepend_path('TVROOT',
                         join_path(self.prefix, 'toolworks',
                                   'totalview.{}'.format(self.version)))
        env.prepend_path('TVDSVRLAUNCHCMD', 'ssh')

    def install(self, spec, prefix):
        # Assemble install line
        inst_line = [ "./Install",
                      "-directory {}".format(prefix),
                      "-agree -nosymlink" ]

        # Platform specification.
        if spec.target.family == "x86_64":
            inst_line.append( "-platform linux-x86-64" )
        elif spec.target.family == "x86":
            inst_line.append( "-platform linux-x86" )
        elif spec.target.family == "aarch64":
            inst_line.append( "-platform linux-arm64" )
        elif spec.target.family == "ppcle":
            inst_line.append( "-platform linux-powerle" )
        elif spec.target.family == "ppc":
            inst_line.append( "-platform linux-power" )
        else:
            inst_line.append( "-platform linux-x86-64" )

        # Docs are the 'base' install used with every architecture.
        docs_inst = inst_line
        docs_inst.append( "-install doc-pdf" )
        os.system(" ".join(docs_inst))

        # Run install script for totalview and memoryscape (optional).
        with working_dir("./totalview.{}".format(self.version)):

            inst_line.append( "-install totalview" )
            # If including memoryscape.
            if '+memoryscape' in spec:
                inst_line.append( "memoryscape" )

            os.system(" ".join(inst_line))
