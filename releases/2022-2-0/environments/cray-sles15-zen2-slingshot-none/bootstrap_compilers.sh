set -e

module switch PrgEnv-cray PrgEnv-intel
spack compiler find

if ! spack compiler list | grep 'intel@2021\.5\.0'; then 
    echo "Could not find intel@2021.5.0"
    exit 1
fi

module switch PrgEnv-intel PrgEnv-gnu
spack compiler find

if ! spack compiler list | grep 'gcc@11\.2\.0'; then 
    echo "Could not find gcc@11.2.0"
    exit 1
fi

