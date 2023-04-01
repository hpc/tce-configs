# Package Repo

This is a set of Spack package repositories for TCE2-specific packages, organized by the TCE
release. Each release of TCE is tied to a specific version of Spack, and the Spacklemore packages
for that release supplement and patch those available in Spack's builtin package repo. 

After each release of TCE, we do our best to add everything in Spacklemore to Spack's builtin
packages, so the next release won't require quite as many fixes.

## Usage

Doing it this way allows us to install multiple releases of TCE into the same installation tree, 
even with conflicting package definitions.

To manually allow Spack to see this repository, add it to the repos.yaml file for the [global](https://spack.readthedocs.io/en/latest/configuration.html#configuration) Spack installation.  The entry for this repository should prepend the list so that it is searched first before the builtin repo, and should be named 
`tce2-<release`. 

To use packages from this repository, specify the package using the [repo-specifying syntax](https://spack.readthedocs.io/en/latest/repositories.html#namespaces) 'tce2-<release>.[package-name]'.

If you don't want to use packages from this repository, but it's overriding the builtin package you want to install, it can be specified as 'builtin.[package-name]'.
