from spack import *
from spack.pkg.builtin.arm_forge import ArmForge as BuiltinArmForge
import platform


class ArmForge(BuiltinArmForge):

    if platform.machine() == "aarch64":
        version("22.0.1", sha256="89237d85cdecf6481c1aa72f3a7c60145ff2f1efcf588aa382b98ee8046d1bd5")
        version("22.0",   sha256="30328b3f92d3284c632c196690a36bce8f3c83b17f2c810deb31797a9ac69432")
    elif platform.machine() == "ppc64le":
        version("22.0.1", sha256="7499462f2f24a556b504c10e56cce61d8e29630ac99aa7a9a59f60e7ce474877")
        version("22.0",   sha256="dbe1248ba683b2b1374c888805c608252daade47f904fb91a4a4803bf11ea5fa")
    elif platform.machine() == "x86_64":
        version("22.0.1", sha256="8f8a61c159665d3de3bc5334ed97bdb4966bfbdb91b65d32d162d489eb2219ac")
        version("22.0",   sha256="4e63758bd474e9640700673625eb2adfe2bdf875eaacfe67862d184ae08f542f")
