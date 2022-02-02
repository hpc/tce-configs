# TCE Spack Stacks
These are the Spack Stacks configurations used at the Tri-Labs. They are set up to allow 
you to recreate the TCE Spack stacks on the fly, hopefully with consistent 
concretized hashes across the environment given the same inputs. 

# Usage

The `./bin/process.sh` command will set up your stack deployment, given a `facility`,
`environment`, and install location. Multiple environments may be placed in the same 
install location, but facility installs should be separated.

It will then try to concretize that Spack environment and, if successful, try to build and install
it. Most of the spack defaults are facility dependent, and should be set in the facilities `process.cfg` file. Almost all of the information about what gets built lives in the environment directory.

```bash
# Build out the lanl, toss3 spack stack from scratch in /usr/projects/hpctools/production
./bin/process.sh -f lanl -e toss3 -i /usr/projects/hpctools/production
# The environment will be built under /usr/projects/hpctools/production/toss3
```

## Creating a Personal Deployment Area
If you want to experiment with altering the spack stacks, you probably don't want to do so
on top of the production stacks. Instead, use the `./bin/clone.sh` script to clone the
original deployment, so you don't have to rebuild everything. This will create a directory 
with symlinks back to the original installs of spack packages. 

```bash
# Clone the production deployment
./bin/clone.sh /usr/projects/hpctools/production/toss3 /mystack/toss3
# Then just make sure to always override the install path on the command line.
./bin/process.sh -f lanl -e toss3 -i /mystack
```

# Structure

## facilities/'facility-name'/

These directories each contain the files needed to configure Spack at a given
facility, such as at LANL. It includes the Spack configurations specific to each
site and/or deployment of the Spack Stacks. 

### Various Spack Configs

These will automatically be put into place in the spack `etc/spack/` directory, and in some case edited on the fly to configure your spack environment. 

These can include:

 - `compilers.yaml` - Locations for site compilers. 
 - `config.yaml` - General Spack configuration.
 - `mirrors.yaml` - Spack package mirror configuration.
 - `packages.yaml` - External package configurations, preferably by module rather
   than by path.
 - `repos.yaml` - Spack package repos.

### `process.cfg`

Configuration for `./bin/process.sh`. 

This is a shell script, sourced by `./bin/process.sh`, that serves as a place
to set facility specific defaults for that script.  Most importantly, it is
where to set the branch/hash/tag for checking out the Spack software itself. To 
see what variables process.sh picks up, see `./bin/process.sh --help`.

### `licenses/`

Site specific software license files. Spack needs license files for some compilers
and software. These will be installed in the stack automatically.

## environments/'env-name'/

Each environment includes a `spack.yaml` file that forms the basis of a Spack stack 
on a certain type of cluster.  These should be independent of facility.  

For a full description of each environment, see below.

### `spack.yaml`

This is the Spack Environment configuration file. It should:

 - Define which packages and versions of packages to include in the environment.
 - Define module settings for those packages.

### `setup_compilers.sh`
A (bash) shell script that will be sourced to bootstrap compilers and set them up in Spack.
For each compiler, this needs to do two things:

1. Install the compiler, if needed.
2. Add the compiler to the spack compiler configs.

The script will run within the context of this environment with that environment's already activated
Spack install. 

#### Compiler Bootstrap Installs
For compilers to be spack installed, you need to be careful to ensure it will be configured the
same as the compiler defined in your spack.yaml. This typically means adding the relevant 
variants, but can also mean you need to explicitly define dependencies too.

```bash
# This will get installed as part of the environment defined by the spack.yaml. 
# In the spack.yaml, gcc will depend on this specific configuration of binutils, so it
# MUST be included. Otherwise, gcc@10.2.0 would be rebuilt under a new hash.
spack install gcc@10.2.0 ^binutils+gold+ld+gas~nls
```

#### Compiler Bootraps Configure
There are two main ways to configure you compiler. The first simply involves using the Spack
commands to do so:

```bash
# This is needed to add this gcc to our path.
spack load gcc@10.2.0

# Simply use spack compiler find to the compiler, and install it in the 'site' scope of 
# configs.
spack compiler find --scope=site

# Unload all loaded packages
spack unload -a
```

It is often the case that this is insufficient, as the compiler may not end up listed correctly 
or require additional flags. For that case we provide the `fix_compiler.py` script. It can add,
edit, and delete entries in the compilers.yaml Spack configuration file.

```bash
# Find the binutils directory from the loaded binutils Spack module
binutils_path=$(spack find --loaded --long -p | grep binutils | awk '{ print $3 }')/bin
# Add the path to LD to our compiler config for gcc@10.2.0
python3 fix_compiler.py $SPACK_ROOT/etc/spack/compilers.yaml edit gcc@10.2.0 rhel7 x86_64 \
        --environment='LD=$binutils_path/ld
```

# Environments

### `kodiak`
This Stack is used to build out our software for a TOSS3, Nvidia GPU, Mellanox
cluster at LANL.  Kodiak is the only machine of this kind at LANL, so it has
been named to be that specific.  The `spack.yaml` configuration file is in this
directory along with the LANL lockfile `spack.lock.lanl` as well as the basic
`process.sh` script used to concretize and install the stacks while capturing
the output and as much information as possible for debugging purposes.  As the
Totalview source code is not able to be downloaded by Spack installs, it is
included in the repository and symlinked into this directory.

## `toss`
The relevant configs for building out the Stack for Infiniband-connected TOSS3
cluster.  The respective files have similar descriptions as those in the
`kodiak` directory.

## `xc40`
The relevant configs for building out the Stack for XC40 systems including
Trinity and Trinitite.  These configs use the Cray-provided compilers and
MPI (cray-mpich) and build the stacks on those.  For now, that excludes the
cray compiler, so only GCC and Intel are used.

## `xc50`
The relevant configs for building out the Stack for XC50 systems include
Capulin and Thunder.  These configs use the Cray-provided GCC compiler and
cray-mpich MPI.
