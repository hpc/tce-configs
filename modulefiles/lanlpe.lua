-- vi: expandtab shiftwidth=2 softtabstop=2

-- This modulefile sets up the environment to use tce.
-- It also removes the previous modulefile environment.

conflict("lanlpe")

whatis("Loading this modulefile enables software in the TCE LANL Programming Environment.")
whatis("Any legacy LANL Programming Environment paths will be unused.")
help([[
After loading this modulefile, perform a `module avail` to see available modulefiles.
To change back to the legacy LANL Programming Environment, please execute `module swap lanlpe/legacy`.
]])

-- Load libraries
local SML = require "/usr/projects/hpcsoft/modulefiles/templates/Standard_Module_Library"
local dirent = require 'posix'.dirent
local glob = require 'posix'.glob

-- Define template variables
local sys_os = SML.systemOS()
local machine = SML.machineName()
local tce_version = myModuleVersion()
local module_dir = "/usr/projects/hpcsoft/modulefiles"
local install_dir = "/usr/projects/hpcsoft/tce"


-- Define template functions
function append_toolchain_path(modulepath)
  if not isDir(modulepath) then
    LmodError(modulepath.. " doesn't exist. Please report this error to consult@lanl.gov.")
  end
  append_path("MODULEPATH", modulepath)
end

-- Remove Legacy path from MODULEPATH
if ( mode() == "load" ) then
  local legacy_dirs = {"debugger", "libraries", "misc", "tools", "viz"}
  for _, dir in pairs(legacy_dirs) do
    remove_path("MODULEPATH", pathJoin(module_dir,sys_os,machine,dir))
  end

  -- On some machines, need to add the compiler and mpi directories to the list
  if sys_os:match "^toss" then
    local toss_legacy_dirs = {"compiler", "mpi"}
    for _, dir in pairs(toss_legacy_dirs) do
      remove_path("MODULEPATH", pathJoin(module_dir,sys_os,machine,dir))
    end
  end
end

-- Define TCE machine string
local machine_table = {
  badger =      "linux-rhel7-x86_64_v3-omnipath-none",
  capulin =     "cray-cnl7-aarch64-aries-none",
  fog =         "linux-rhel7-x86_64_v3-omnipath-none",
  grizzly =     "linux-rhel7-x86_64_v3-omnipath-none",
  kodiak =      "linux-rhel7-x86_64_v3-infiniband-nvidia_v6.0",
  snow =        "linux-rhel7-x86_64_v3-omnipath-none",
  trinitite =   "cray-cnl7-x86_64_v3-aries-none",
  cyclone =     "linux-rhel7-x86_64_v3-omnipath-none",
  fire =        "linux-rhel7-x86_64_v3-omnipath-none",
  ice =         "linux-rhel7-x86_64_v3-omnipath-none",
  thunder =     "cray-cnl7-aarch64-aries-none",
  trinity =     "cray-cnl7-x86_64_v3-aries-none",
  chicoma =     "cray-sles15-x86_64_v3-slingshot-none",
  rocinante =   "cray-sles15-x86_64_v3-slingshot-none"
}
local machine_string = machine_table[machine]
if not machine_string then
  LmodError("Unable to determine TCE machine type. Please report this error to consult@lanl.gov.")
end

-- Define Spack machine architecture
local spack_arch_table = {
  badger =      "linux-rhel7-x86_64",
  capulin =     "cray-cnl7-aarch64",
  fog =         "linux-rhel7-x86_64",
  grizzly =     "linux-rhel7-x86_64",
  kodiak =      "linux-rhel7-x86_64",
  snow =        "linux-rhel7-x86_64",
  trinitite =   "cray-cnl7-haswell",
  cyclone =     "linux-rhel7-x86_64",
  fire =        "linux-rhel7-x86_64",
  ice =         "linux-rhel7-x86_64",
  thunder =     "cray-cnl7-aarch64",
  trinity =     "cray-cnl7-haswell",
  chicoma =     "linux-sles15-x86_64",
  rocinante =   "linux-sles15-x86_64"
}
local spack_arch = spack_arch_table[machine]
if not spack_arch then
  LmodError("Unable to determine the Spack architecture of this machine. Please report this error to consult@lanl.gov.")
end


-- Add TCE Core modulefiles to MODULEPATH
local tce_mod_dir = pathJoin(install_dir,tce_version,machine_string,"modulefiles")
if not isDir(tce_mod_dir) then
  LmodError(tce_mod_dir.. "is not a valid path. Please report this error to consult@lanl.gov.")
end
local tce_core_path = pathJoin(tce_mod_dir,spack_arch,"Core")
if not isDir(tce_core_path) then
  LmodError("Attempting to add " ..tce_core_path .. " to MODULEPATH, but it doesn't exist. Please report this error to consult@lanl.gov.")
end
append_path("MODULEPATH", tce_core_path)


-- Start building TCE toolchains modulefiles paths
local toolchains_dir = pathJoin(tce_mod_dir,"toolchains",spack_arch)
if not isDir(toolchains_dir) then
  LmodError(toolchains_dir.. " is not a valid path. Please report this error to consult@lanl.gov.")
end

-- Define table to map Spack-defined compilers to their system counter-parts
local compiler_remap_table = {
    ["cce-15.0.0"] =                {name = "cce",              version = "15.0.0"},
    ["gcc-11.2.0"] =                {name = "gcc",              version = "11.2.0"},
    ["intel-2022.2.1"] =            {name = "intel",            version = "2022.2.1"},
    ["intel-19.1.3"] =              {name = "intel",            version = "19.1.3"},
    ["intel-2021.7.1.classic"] =    {name = "intel-classic",    version = "2022.2.1"},
    ["intel-2021.9.0.classic"] =    {name = "intel-classic",    version = "2022.2.1"},
    ["oneapi-2022.2.1"] =           {name = "intel-oneapi",     version = "2022.2.1"},
    ["oneapi-2023.1.0"] =           {name = "intel-oneapi",     version = "2023.1.0"}
}

-- Procedurally build table of TCE toolchains mpi x compiler modulepaths
local re = "[^%.][%w%d-_.]*"
local holy_table = {}
for _,dir in pairs(dirent.dir(toolchains_dir)) do
    for mpi in string.gmatch(dir, re) do 
        for _,dir in pairs(dirent.dir(pathJoin(toolchains_dir,mpi))) do
            for raw_mpi_hash in string.gmatch(dir,re) do
                local mpi_hash_table = SML.split(raw_mpi_hash, "-")
                local mpi_version = mpi_hash_table[1]
                local mpi_hash = mpi_hash_table[2]
                for _,dir in pairs(dirent.dir(pathJoin(toolchains_dir,mpi,raw_mpi_hash))) do
                    for compiler in string.gmatch(dir,re) do
                        for _,dir in pairs(dirent.dir(pathJoin(toolchains_dir,mpi,raw_mpi_hash,compiler))) do
                            for version in string.gmatch(dir,re) do
                                local comp_ver = compiler.."-"..version
                                local sys_comp_name = compiler_remap_table[comp_ver].name
                                local sys_comp_version = compiler_remap_table[comp_ver].version
                                holy_table[comp_ver] = {
                                                        sys_comp_name = sys_comp_name, 
                                                        sys_comp_version = sys_comp_version, 
                                                        spack_comp_name = compiler, 
                                                        spack_comp_version = version, 
                                                        mpi_name = mpi, 
                                                        mpi_version = mpi_version, 
                                                        mpi_hash = mpi_hash
                                                       }
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Join values generated in previous table together to form the new modulepaths
local tce_module_path = {}
for _,value in pairs(holy_table) do
    tce_module_path[_] = pathJoin(tce_mod_dir,"toolchains",spack_arch,value.mpi_name,value.mpi_version.."-"..value.mpi_hash,value.spack_comp_name,value.spack_comp_version)
end

-- Add TCE toolchains modulepaths to MODULEPATH 
-- and remove TCE toolchains modulepaths that don't belong
for key, value in pairs(holy_table) do
    if isloaded(pathJoin(value.sys_comp_name,value.sys_comp_version)) then
        append_toolchain_path(tce_module_path[key])
    else 
        remove_path("MODULEPATH",tce_module_path[key])
    end
end

-- Usage logging
-- SML.usage_logging("lanlpe", "2023-2-0")
