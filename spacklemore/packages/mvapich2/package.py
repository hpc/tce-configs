import sys
from spack import *
from spack.pkg.builtin.mvapich2 import Mvapich2 as BuiltinMvapich2

class Mvapich2(BuiltinMvapich2):
    """TCE-specific modifications to the mvapich2 package."""

    def setup_run_environment(self, env):
        env.set('MPI_ROOT', self.prefix)
