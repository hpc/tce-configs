from spack import *
from spack.pkg.builtin.arm_forge import ArmForge as BuiltinArmForge
import platform


class ArmForge(BuiltinArmForge):

    if platform.machine() == "aarch64":
        version("21.0.3", sha256="371f4e3087af329bee155ceb50b9adaf006d3b8602fb1b6bbdc710ab0f74368d")
