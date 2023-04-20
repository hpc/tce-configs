# Package Repo

This is a set of Spack package repositories for TCE2-specific packages, organized by the TCE
release. Each release of TCE is tied to a specific version of Spack, and the Spacklemore packages
for that release supplement and patch those available in Spack's builtin package repo. 

After each release of TCE, we do our best to add everything in Spacklemore to Spack's builtin
packages, so the next release won't require quite as many fixes.

## Usage

If using TCE upstreams or the TCE buildcache, you'll need to include these repos in your repos.yaml
file. TCE releases should list the repo tied to that release first, followed by the builtin repo,
and finally followed by all other TCE repos. That way builds for that release will always use the
correct repo, and just have the others available so that Spack can resolve the namespace. 

For Spack builds that simply upstream against TCE or use a TCE buildcache, simply include the list
of these repos after any of yours and the builtin repo. If you would like to use a package as
defined in one of these repos, specify it with the repo as a prefix: `tce-2023-1.gcc`, for example.
