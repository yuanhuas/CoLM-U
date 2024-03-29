#include <define.h>

MODULE UrbanLCZ_Const

  ! -----------------------------------------------------------------------
  ! !DESCRIPTION:
  ! look-up-table for LCZ morphology and thermal parameters
  ! !NOTE!!!!!!!!!!!!!!!
  ! Each city may have different values for the parameters in this table.
  ! The default values may not suit any specific city.
  ! Users could adjust these values based on the city they are working with.
  !
  ! ORIGINAL:
  ! Wenzong Dong, Jun, 2022
  !-----------------------------------------------------------------------
  ! REFERENCES:
  ! 1) Stewart, I. D., Oke, T. R., & Krayenhoff, E. S. (2014). Evaluation of the ‘local climate zone’ scheme
  ! using temperature observations and model simulations. International Journal of Climatology,
  ! 34(4), 1062–1080. https://doi.org/10.1002/joc.3746
  ! 2) The URBPARM_LCZ.TBL of WRF, https://github.com/wrf-model/WRF/
  !
  ! -----------------------------------------------------------------------
  ! !USE
   USE precision

   IMPLICIT NONE
   SAVE

   ! roof fraction [-]
   REAL(r8), parameter, dimension(10) :: rooffrac &
      = (/0.5 , 0.5 , 0.55, 0.3 , 0.3, 0.3, 0.8 , 0.4 , 0.15, 0.25/)

   ! pervious fraction [-]
   REAL(r8), parameter, dimension(10)  :: perfrac &
      = (/0.05, 0.1 , 0.15, 0.35, 0.3, 0.4, 0.15, 0.15, 0.7 , 0.45/)

   ! height of roof [m]
   REAL(r8), parameter, dimension(10)  :: roofhgt &
      = (/45., 15. , 5.  , 40., 15., 5. , 3. , 7. , 5.  , 8.5 /)

   ! H/W [-]
   REAL(r8), parameter, dimension(10)  :: h2w &
      = (/2.5, 1.25, 1.25, 1. , 0.5, 0.5, 1.5, 0.2, 0.15, 0.35/)

   ! thickness of roof [m]
   REAL(r8), parameter, dimension(10)  :: rooftk &
      = (/0.3 , 0.3 , 0.2 , 0.3 , 0.25, 0.15, 0.05, 0.12, 0.15, 0.05/)

   ! thickness of wall [m]
   REAL(r8), parameter, dimension(10)  :: walltk &
      = (/0.3 , 0.25, 0.2 , 0.2 , 0.2 , 0.2 , 0.1 , 0.2 , 0.2 , 0.05/)

   ! thickness of impervious road [m]
   REAL(r8), parameter, dimension(10)  :: roadtk &
      = (/0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25/)

   ! albeodo of roof [-]
   REAL(r8), parameter, dimension(10)  :: roofalb &
      = (/0.13, 0.18, 0.15, 0.13, 0.13, 0.13, 0.15, 0.18, 0.13, 0.1 /)

   ! albeodo of wall [-]
   REAL(r8), parameter, dimension(10)  :: wallalb &
      = (/0.25, 0.2 , 0.2 , 0.25, 0.25, 0.25, 0.2 , 0.25, 0.25, 0.2 /)

   ! albeodo of impervious road [-]
   REAL(r8), parameter, dimension(10)  :: roadalb &
      = (/0.15, 0.15, 0.18, 0.20, 0.20, 0.21, 0.24, 0.17, 0.23, 0.21/)

   ! albeodo of pervious road [-]
   REAL(r8), parameter, dimension(10)  :: peralb &
      = (/0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08/)

   ! emissivity of roof [-]
   REAL(r8), parameter, dimension(10)  :: roofem &
      = (/0.91, 0.91, 0.91, 0.91, 0.91, 0.91, 0.28, 0.91, 0.91, 0.91/)

   ! emissivity of roof [-]
   REAL(r8), parameter, dimension(10)  :: wallem &
      = (/0.90, 0.90, 0.90, 0.90, 0.90, 0.90, 0.90, 0.90, 0.90, 0.90/)

   ! emissivity of wall [-]
   REAL(r8), parameter, dimension(10)  :: roadem &
      = (/0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.92, 0.95, 0.95, 0.95/)

   ! emissivity of impervious road [-]
   REAL(r8), parameter, dimension(10)  :: perem &
      = (/0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95, 0.95/)


   ! volumetric heat capacity of roof [J/m3*K]
   REAL(r8), parameter, dimension(10)  :: roofcv &
      = (/1.8E6 , 1.8E6 , 1.44E6, 1.8E6 , 1.8E6 , 1.44E6, 2.0E6 , 1.8E6 , 1.44E6, 2.0E6 /)

   ! volumetric heat capacity of wall [J/m3*K]
   REAL(r8), parameter, dimension(10)  :: wallcv &
      = (/1.8E6 , 2.67E6, 2.05E6, 2.0E6 , 2.0E6 , 2.05E6, 0.72E6, 1.8E6 , 2.56E6, 1.69E6/)

   ! volumetric heat capacity of impervious road [J/m3*K]
   REAL(r8), parameter, dimension(10)  :: roadcv &
      = (/1.75E6, 1.68E6, 1.63E6, 1.54E6, 1.50E6, 1.47E6, 1.67E6, 1.38E6, 1.37E6, 1.49E6/)


   ! thermal conductivity of roof [W/m*K]
   REAL(r8), parameter, dimension(10)  :: throof &
      = (/1.25, 1.25, 1.00, 1.25, 1.25, 1.00, 2.0 , 1.25, 1.00, 2.00/)

   ! thermal conductivity of wall [W/m*K]
   REAL(r8), parameter, dimension(10)  :: thwall &
      = (/1.09, 1.5 , 1.25, 1.45, 1.45, 1.25, 0.5 , 1.25, 1.00, 1.33/)

   ! thermal conductivity of impervious road [W/m*K]
   REAL(r8), parameter, dimension(10)  :: throad &
      = (/0.77, 0.73, 0.69, 0.64, 0.62, 0.60, 0.72, 0.51, 0.55, 0.61/)


   !TODO:AHE coding

END MODULE UrbanLCZ_Const
