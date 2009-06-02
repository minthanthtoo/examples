!> \file
!> $Id: LagrangeSimplexMeshExample.f90 20 2007-05-28 20:22:52Z cpb $
!> \author Chris Bradley
!> \brief This is an example program which sets up a field which uses a mixed Lagrange and Simplex mesh using openCMISS calls.
!>
!> \section LICENSE
!>
!> Version: MPL 1.1/GPL 2.0/LGPL 2.1
!>
!> The contents of this file are subject to the Mozilla Public License
!> Version 1.1 (the "License"); you may not use this file except in
!> compliance with the License. You may obtain a copy of the License at
!> http://www.mozilla.org/MPL/
!>
!> Software distributed under the License is distributed on an "AS IS"
!> basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
!> License for the specific language governing rights and limitations
!> under the License.
!>
!> The Original Code is OpenCMISS
!>
!> The Initial Developer of the Original Code is University of Auckland,
!> Auckland, New Zealand and University of Oxford, Oxford, United
!> Kingdom. Portions created by the University of Auckland and University
!> of Oxford are Copyright (C) 2007 by the University of Auckland and
!> the University of Oxford. All Rights Reserved.
!>
!> Contributor(s):
!>
!> Alternatively, the contents of this file may be used under the terms of
!> either the GNU General Public License Version 2 or later (the "GPL"), or
!> the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
!> in which case the provisions of the GPL or the LGPL are applicable instead
!> of those above. If you wish to allow use of your version of this file only
!> under the terms of either the GPL or the LGPL, and not to allow others to
!> use your version of this file under the terms of the MPL, indicate your
!> decision by deleting the provisions above and replace them with the notice
!> and other provisions required by the GPL or the LGPL. If you do not delete
!> the provisions above, a recipient may use your version of this file under
!> the terms of any one of the MPL, the GPL or the LGPL.
!>

!> \example LagrangeSimplexMesh/src/LagrangeSimplexMeshExample.f90
!! Example program which sets up a field which uses a mixed Lagrange and Simplex mesh using openCMISS calls.
!<

!> Main program
PROGRAM LAGRANGESIMPLEXMESHEXAMPLE

  USE BASE_ROUTINES
  USE BASIS_ROUTINES
  USE CMISS
  USE CMISS_MPI
  USE COMP_ENVIRONMENT
  USE CONSTANTS
  USE CONTROL_LOOP_ROUTINES
  USE COORDINATE_ROUTINES
  USE DISTRIBUTED_MATRIX_VECTOR
  USE DOMAIN_MAPPINGS
  USE EQUATIONS_ROUTINES
  USE EQUATIONS_SET_CONSTANTS
  USE EQUATIONS_SET_ROUTINES
  USE FIELD_ROUTINES
  USE FIELD_IO_ROUTINES
  USE GENERATED_MESH_ROUTINES
  USE INPUT_OUTPUT
  USE ISO_VARYING_STRING
  USE KINDS
  USE LISTS
  USE MESH_ROUTINES
  USE MPI
  USE NODE_ROUTINES
  USE PROBLEM_CONSTANTS
  USE PROBLEM_ROUTINES
  USE REGION_ROUTINES
  USE SOLVER_ROUTINES
  USE TIMER
  USE TYPES

#ifdef WIN32
  USE IFQWIN
#endif

  IMPLICIT NONE

  !Test program parameters

  !Program types
  
  !Program variables
  
  INTEGER(INTG) :: NUMBER_COMPUTATIONAL_NODES
  INTEGER(INTG) :: MY_COMPUTATIONAL_NODE_NUMBER
 
  TYPE(BASIS_TYPE), POINTER :: BASIS1,BASIS2
  TYPE(COORDINATE_SYSTEM_TYPE), POINTER :: COORDINATE_SYSTEM
  TYPE(MESH_TYPE), POINTER :: MESH
  TYPE(MESH_ELEMENTS_TYPE), POINTER :: MESH_ELEMENTS
  TYPE(NODES_TYPE), POINTER :: NODES
  TYPE(DECOMPOSITION_TYPE), POINTER :: DECOMPOSITION
  TYPE(FIELD_TYPE), POINTER :: GEOMETRIC_FIELD
  TYPE(REGION_TYPE), POINTER :: REGION,WORLD_REGION
   
  LOGICAL :: EXPORT_FIELD
  TYPE(VARYING_STRING) :: FILE,METHOD

  REAL(SP) :: START_USER_TIME(1),STOP_USER_TIME(1),START_SYSTEM_TIME(1),STOP_SYSTEM_TIME(1)

#ifdef WIN32
  !Quickwin type
  LOGICAL :: QUICKWIN_STATUS=.FALSE.
  TYPE(WINDOWCONFIG) :: QUICKWIN_WINDOW_CONFIG
#endif
  
  !Generic CMISS variables
  
  INTEGER(INTG) :: ERR
  TYPE(VARYING_STRING) :: ERROR

  INTEGER(INTG) :: DIAG_LEVEL_LIST(5)
  CHARACTER(LEN=MAXSTRLEN) :: DIAG_ROUTINE_LIST(1),TIMING_ROUTINE_LIST(1)
  
#ifdef WIN32
  !Initialise QuickWin
  QUICKWIN_WINDOW_CONFIG%TITLE="General Output" !Window title
  QUICKWIN_WINDOW_CONFIG%NUMTEXTROWS=-1 !Max possible number of rows
  QUICKWIN_WINDOW_CONFIG%MODE=QWIN$SCROLLDOWN
  !Set the window parameters
  QUICKWIN_STATUS=SETWINDOWCONFIG(QUICKWIN_WINDOW_CONFIG)
  !If attempt fails set with system estimated values
  IF(.NOT.QUICKWIN_STATUS) QUICKWIN_STATUS=SETWINDOWCONFIG(QUICKWIN_WINDOW_CONFIG)
#endif

  !Intialise cmiss
  NULLIFY(WORLD_REGION)
  CALL CMISS_INITIALISE(WORLD_REGION,ERR,ERROR,*999)
  
  !Set all diganostic levels on for testing
  !DIAG_LEVEL_LIST(1)=1
  !DIAG_LEVEL_LIST(2)=2
  !DIAG_LEVEL_LIST(3)=3
  !DIAG_LEVEL_LIST(4)=4
  !DIAG_LEVEL_LIST(5)=5
  !DIAG_ROUTINE_LIST(1)=""
  !CALL DIAGNOSTICS_SET_ON(ALL_DIAG_TYPE,DIAG_LEVEL_LIST,"LagrangeSimplexMeshExample",DIAG_ROUTINE_LIST,ERR,ERROR,*999)
  !CALL DIAGNOSTICS_SET_ON(ALL_DIAG_TYPE,DIAG_LEVEL_LIST,"",DIAG_ROUTINE_LIST,ERR,ERROR,*999)
 
  !TIMING_ROUTINE_LIST(1)=""
  !CALL TIMING_SET_ON(IN_TIMING_TYPE,.TRUE.,"",TIMING_ROUTINE_LIST,ERR,ERROR,*999)
  
  !Calculate the start times
  CALL CPU_TIMER(USER_CPU,START_USER_TIME,ERR,ERROR,*999)
  CALL CPU_TIMER(SYSTEM_CPU,START_SYSTEM_TIME,ERR,ERROR,*999)
  
  !Get the number of computational nodes
  NUMBER_COMPUTATIONAL_NODES=COMPUTATIONAL_NODES_NUMBER_GET(ERR,ERROR)
  IF(ERR/=0) GOTO 999
  !Get my computational node number
  MY_COMPUTATIONAL_NODE_NUMBER=COMPUTATIONAL_NODE_NUMBER_GET(ERR,ERROR)
  IF(ERR/=0) GOTO 999

  !Start the creation of a new RC coordinate system
  NULLIFY(COORDINATE_SYSTEM)
  CALL COORDINATE_SYSTEM_CREATE_START(1,COORDINATE_SYSTEM,ERR,ERROR,*999)
  !Set the coordinate system to be 2D
  CALL COORDINATE_SYSTEM_DIMENSION_SET(COORDINATE_SYSTEM,2,ERR,ERROR,*999)
  !Finish the creation of the coordinate system
  CALL COORDINATE_SYSTEM_CREATE_FINISH(COORDINATE_SYSTEM,ERR,ERROR,*999)

  !Start the creation of a region
  NULLIFY(REGION)
  CALL REGION_CREATE_START(1,WORLD_REGION,REGION,ERR,ERROR,*999)
  !Set the regions coordinate system to the RC coordinate system that we have created
  CALL REGION_COORDINATE_SYSTEM_SET(REGION,COORDINATE_SYSTEM,ERR,ERROR,*999)
  !Finish the creation of the region
  CALL REGION_CREATE_FINISH(REGION,ERR,ERROR,*999)
  
  !Start the creation of a linear-quadratic Lagrange basis
  NULLIFY(BASIS1)
  CALL BASIS_CREATE_START(1,BASIS1,ERR,ERROR,*999)
  !Set the basis to be a 2D basis
  CALL BASIS_NUMBER_OF_XI_SET(BASIS1,2,ERR,ERROR,*999)
  !Set the interpolation to be linear-quadratic
  CALL BASIS_INTERPOLATION_XI_SET(BASIS1,(/BASIS_LINEAR_LAGRANGE_INTERPOLATION,BASIS_QUADRATIC_LAGRANGE_INTERPOLATION/), &
    & ERR,ERROR,*999)
  !Finish the creation of the basis
  CALL BASIS_CREATE_FINISH(BASIS1,ERR,ERROR,*999)

  !Start the creation of a quadratic Simplex triangle basis
  NULLIFY(BASIS2)
  CALL BASIS_CREATE_START(2,BASIS2,ERR,ERROR,*999)
  !Set the basis to be of Simplex type
  CALL BASIS_TYPE_SET(BASIS2,BASIS_SIMPLEX_TYPE,ERR,ERROR,*999)
  !Set the basis to be a triangluar basis
  CALL BASIS_NUMBER_OF_XI_SET(BASIS2,2,ERR,ERROR,*999)
  !Set the interpolation to be quadratic
  CALL BASIS_INTERPOLATION_XI_SET(BASIS2,(/BASIS_QUADRATIC_SIMPLEX_INTERPOLATION,BASIS_QUADRATIC_SIMPLEX_INTERPOLATION/), &
    & ERR,ERROR,*999)
  !Finish the creation of the basis
  CALL BASIS_CREATE_FINISH(BASIS2,ERR,ERROR,*999)

  !Create a mesh. The mesh will consist of a linear-quadratic Lagrange element and a quadratic Simplex element i.e.,
  !
  !  8-------9
  !  |       |\
  !  |       | \
  !  |       |  \
  !  5   e1  6   7
  !  |       |    \
  !  |       | e2  \
  !  |       |      \
  !  1-------2---3---4
  !
  NULLIFY(NODES)
  CALL NODES_CREATE_START(REGION,9,NODES,ERR,ERROR,*999)
  CALL NODES_CREATE_FINISH(NODES,ERR,ERROR,*999)
  NULLIFY(MESH)
  NULLIFY(MESH_ELEMENTS)
  CALL MESH_CREATE_START(1,REGION,2,MESH,ERR,ERROR,*999)
  CALL MESH_NUMBER_OF_ELEMENTS_SET(MESH,2,ERR,ERROR,*999)
  CALL MESH_TOPOLOGY_ELEMENTS_CREATE_START(MESH,1,BASIS1,MESH_ELEMENTS,ERR,ERROR,*999)
  CALL MESH_TOPOLOGY_ELEMENTS_ELEMENT_NODES_SET(1,MESH_ELEMENTS,(/1,2,5,6,8,9/),ERR,ERROR,*999)
  CALL MESH_TOPOLOGY_ELEMENTS_ELEMENT_BASIS_SET(2,MESH_ELEMENTS,BASIS2,ERR,ERROR,*999)
  CALL MESH_TOPOLOGY_ELEMENTS_ELEMENT_NODES_SET(2,MESH_ELEMENTS,(/9,2,4,6,3,7/),ERR,ERROR,*999)
  CALL MESH_TOPOLOGY_ELEMENTS_CREATE_FINISH(MESH,1,ERR,ERROR,*999)
  CALL MESH_CREATE_FINISH(MESH,ERR,ERROR,*999)

  !Create a decomposition for mesh
  NULLIFY(DECOMPOSITION)
  CALL DECOMPOSITION_CREATE_START(1,MESH,DECOMPOSITION,ERR,ERROR,*999)
  !Set the decomposition to be a general decomposition with the specified number of domains
  CALL DECOMPOSITION_TYPE_SET(DECOMPOSITION,DECOMPOSITION_CALCULATED_TYPE,ERR,ERROR,*999)
  CALL DECOMPOSITION_NUMBER_OF_DOMAINS_SET(DECOMPOSITION,NUMBER_COMPUTATIONAL_NODES,ERR,ERROR,*999)
  !Finish the decomposition creation
  CALL DECOMPOSITION_CREATE_FINISH(MESH,DECOMPOSITION,ERR,ERROR,*999)

  !Start to create a default (geometric) field on the region
  NULLIFY(GEOMETRIC_FIELD)
  CALL FIELD_CREATE_START(1,REGION,GEOMETRIC_FIELD,ERR,ERROR,*999)
  !Set the decomposition to use
  CALL FIELD_MESH_DECOMPOSITION_SET(GEOMETRIC_FIELD,DECOMPOSITION,ERR,ERROR,*999)
  !Set the mesh components to be used by the field components
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,1,1,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,2,1,ERR,ERROR,*999)
  !Finish creating the field
  CALL FIELD_CREATE_FINISH(GEOMETRIC_FIELD,ERR,ERROR,*999)

  !Set the geometric field values
  !X values
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,1,1,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,2,1,1.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,3,1,1.5_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,4,1,2.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,5,1,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,6,1,1.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,7,1,1.5_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,8,1,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,9,1,1.0_DP,ERR,ERROR,*999)
  !Y values
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,1,2,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,2,2,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,3,2,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,4,2,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,5,2,0.5_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,6,2,0.5_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,7,2,0.5_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,8,2,1.0_DP,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,9,2,1.0_DP,ERR,ERROR,*999)
  
  CALL FIELD_PARAMETER_SET_UPDATE_START(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_FINISH(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
 
  EXPORT_FIELD=.TRUE.
  METHOD="FORTRAN"
  IF(EXPORT_FIELD) THEN
    FILE="LagrangeSimplexMeshExample"
    CALL FIELD_IO_NODES_EXPORT(REGION%FIELDS, FILE, METHOD, ERR,ERROR,*999)  
    CALL FIELD_IO_ELEMENTS_EXPORT(REGION%FIELDS, FILE, METHOD, ERR,ERROR,*999)
  ENDIF
  
  !Calculate the stop times and write out the elapsed user and system times
  CALL CPU_TIMER(USER_CPU,STOP_USER_TIME,ERR,ERROR,*999)
  CALL CPU_TIMER(SYSTEM_CPU,STOP_SYSTEM_TIME,ERR,ERROR,*999)

  CALL WRITE_STRING_TWO_VALUE(GENERAL_OUTPUT_TYPE,"User time = ",STOP_USER_TIME(1)-START_USER_TIME(1),", System time = ", &
    & STOP_SYSTEM_TIME(1)-START_SYSTEM_TIME(1),ERR,ERROR,*999)
  
  CALL CMISS_FINALISE(ERR,ERROR,*999)

  WRITE(*,'(A)') "Program successfully completed."
  
  STOP
999 CALL CMISS_WRITE_ERROR(ERR,ERROR)
  STOP
  
END PROGRAM LAGRANGESIMPLEXMESHEXAMPLE
