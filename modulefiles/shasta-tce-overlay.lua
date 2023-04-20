-- This modulefile is meant to be loaded an overlay on the cray (or PREteam) provided
-- module files. For that to happen, the following must be true:
--  1. The module file path with modules that use this must be listed earlier in MODULEPATH 
--     than the original modules. 
--  2. There  must be original modules to inherit from.
--  3. If the original module is a the default, then the overlay module must also be marked as
--     the default (thus becoming the true default). 
--
-- This will add the appropriate LANL_Core path to the MODULEPATH, forcing all modules under 
-- that path to reload whenever this module is loaded or unloaded (or swapped). This allows 
-- the LANL_Core modules to automatically adjust to changes in compiler and MPI.

-- This causes this file to inherit the entirety of the upstream module file. You 
-- don't have to specify what that module file is.

inherit()

local sml = require "/usr/projects/hpcsoft/modulefiles/templates/Standard_Module_Library"

local sys_name = sml.systemOS()
local sys_os = sml.machineName()

local lanl_core_path = '/usr/projects/hpcsoft/modulesfiles/' .. sys_os .. '/' ..
                       sys_name .. '/LANL_Core'

-- By adding the lanl_core_path here, any time this is loaded/unloaded/swapped it will cause
-- all modulefiles loaded under the core path to reload. 
append_path('MODULEPATH', lanl_core_path)

-- When we're not loading cray-mpich, set up the overlay modulepath for cray-mpich.
-- This can't be added to the modulepath until after a compiler has been.
if myModuleName != 'cray-mpich' then
    local overlay_mpi = '/usr/projects/hpcsoft/modulefiles/' .. sys_os .. '/' ..
                        sys_name .. 'overlay_mpi'
    append_path('MODULEPATH', mpi_overlay)
end

