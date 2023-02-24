# Release Compilers and MPIs

Each release will try to pick a consistent set of compilers and MPIs though not all apply to all
system types. 

## 2022-2-a (alpha release)

This release only targets Cray Shasta environments.  

The 2022-2-0 release will be updated to target the compiler/mpi versions in CPE/2022.11. 

### Compilers

 - gcc@11.2.0 (base)
 - intel@2021.5.0 
 - intel-classic@2021.5.0 
 - oneapi@2022.0.0
 - intel@19.1.3
 - aocc (where applicable)
 - nvidia (where applicable)

Note: Spack can't currently tell the difference between intel-classic and basic intel compilers. 

### MPIs

 - cray-mpich@8.1.14

## 2022-1-0 (initial release)

### Compilers

 - gcc@10.3.0 (base)
 - intel@2021.2.0 (toss3)
 - llvm@12.0.0 - ie clang (toss3)
 - intel@19.1.3 (cray)
 - cce@11.0.4 (cray)
 - cce@12.0.3 (cray)

### MPIs

 - openmpi@4.1.1 (toss3)
 - intel-mpi@2021.2.0
 - mvapich2@2.3.6
 - cray-mpich@7.7.18 (cray)
 - cray-mpich@7.7.17 (cray)
