#include <define.h>

MODULE MOD_TimeInvariants
! -------------------------------
! Created by Yongjiu Dai, 03/2014
! -------------------------------

  USE precision
  IMPLICIT NONE
  SAVE
! -----------------------------------------------------------------
! surface classification and soil information
  INTEGER,  allocatable :: patch2lon      (:)  !patch longitude index
  INTEGER,  allocatable :: patch2lat      (:)  !patch latitude index
  INTEGER,  allocatable :: patchclass     (:)  !index of land cover type
  INTEGER,  allocatable :: patchtype      (:)  !land water type
  INTEGER,  allocatable :: grid_patch_s (:,:)  !start patch number of grid
  INTEGER,  allocatable :: grid_patch_e (:,:)  !end patch number of grid
  REAL(r8), allocatable :: gridarea     (:,:)  !area of grid cell the patch located in
  REAL(r8), allocatable :: patchfrac      (:)  !patch weight

  REAL(r8), allocatable :: patchlatr      (:)  !latitude in radians
  REAL(r8), allocatable :: patchlonr      (:)  !longitude in radians
  REAL(r8), allocatable :: gridlatd       (:)  !latitude in degrees
  REAL(r8), allocatable :: gridlond       (:)  !longitude in degrees

  REAL(r8), allocatable :: lakedepth      (:)  !lake depth
  REAL(r8), allocatable :: dz_lake      (:,:)  !new lake scheme

  REAL(r8), allocatable :: soil_s_v_alb   (:)  !albedo of visible of the saturated soil
  REAL(r8), allocatable :: soil_d_v_alb   (:)  !albedo of visible of the dry soil
  REAL(r8), allocatable :: soil_s_n_alb   (:)  !albedo of near infrared of the saturated soil
  REAL(r8), allocatable :: soil_d_n_alb   (:)  !albedo of near infrared of the dry soil
  REAL(r8), allocatable :: porsl        (:,:)  !fraction of soil that is voids [-]
  REAL(r8), allocatable :: psi0         (:,:)  !minimum soil suction [mm] (NOTE: "-" valued)
  REAL(r8), allocatable :: bsw          (:,:)  !clapp and hornbereger "b" parameter [-]
  REAL(r8), allocatable :: hksati       (:,:)  !hydraulic conductivity at saturation [mm h2o/s]
  REAL(r8), allocatable :: csol         (:,:)  !heat capacity of soil solids [J/(m3 K)]
  REAL(r8), allocatable :: dksatu       (:,:)  !thermal conductivity of saturated soil [W/m-K]
  REAL(r8), allocatable :: dkdry        (:,:)  !thermal conductivity for dry soil [W/(m-K)]

  REAL(r8), allocatable :: htop           (:)  !canopy top height [m]
  REAL(r8), allocatable :: hbot           (:)  !canopy bottom height [m]

  REAL(r8) :: zlnd         !roughness length for soil [m]
  REAL(r8) :: zsno         !roughness length for snow [m]
  REAL(r8) :: csoilc       !drag coefficient for soil under canopy [-]
  REAL(r8) :: dewmx        !maximum dew
  REAL(r8) :: wtfact       !fraction of model area with high water table
  REAL(r8) :: capr         !tuning factor to turn first layer T into surface T
  REAL(r8) :: cnfac        !Crank Nicholson factor between 0 and 1
  REAL(r8) :: ssi          !irreducible water saturation of snow
  REAL(r8) :: wimp         !water impremeable if porosity less than wimp
  REAL(r8) :: pondmx       !ponding depth (mm)
  REAL(r8) :: smpmax       !wilting point potential in mm
  REAL(r8) :: smpmin       !restriction for min of soil poten. (mm)
  REAL(r8) :: trsmx0       !max transpiration for moist soil+100% veg. [mm/s]
  REAL(r8) :: tcrit        !critical temp. to determine rain or snow

! PUBLIC MEMBER FUNCTIONS:
  PUBLIC :: allocate_TimeInvariants
  PUBLIC :: deallocate_TimeInvariants
  PUBLIC :: WRITE_TimeInvariants
  PUBLIC :: READ_TimeInvariants

! PRIVATE MEMBER FUNCTIONS:

!-----------------------------------------------------------------------

  CONTAINS

!-----------------------------------------------------------------------

  SUBROUTINE allocate_TimeInvariants
  ! --------------------------------------------------------------------
  ! Allocates memory for CLM 1d [numpatch] variables
  ! --------------------------------------------------------------------

     USE precision
     USE GlobalVars
     USE MOD_PFTimeInvars
     USE MOD_PCTimeInvars
     USE MOD_UrbanTimeInvars
     IMPLICIT NONE

     allocate (patch2lon                 (numpatch))
     allocate (patch2lat                 (numpatch))
     allocate (patchclass                (numpatch))
     allocate (patchtype                 (numpatch))
     allocate (grid_patch_s (lon_points,lat_points))
     allocate (grid_patch_e (lon_points,lat_points))
     allocate (gridarea     (lon_points,lat_points))
     allocate (patchfrac                 (numpatch))

     allocate (patchlatr                 (numpatch))
     allocate (patchlonr                 (numpatch))
     allocate (gridlatd                (lat_points))
     allocate (gridlond                (lon_points))

     allocate (lakedepth                 (numpatch))
     allocate (dz_lake           (nl_lake,numpatch))

     allocate (soil_s_v_alb              (numpatch))
     allocate (soil_d_v_alb              (numpatch))
     allocate (soil_s_n_alb              (numpatch))
     allocate (soil_d_n_alb              (numpatch))
     allocate (porsl             (nl_soil,numpatch))
     allocate (psi0              (nl_soil,numpatch))
     allocate (bsw               (nl_soil,numpatch))
     allocate (hksati            (nl_soil,numpatch))
     allocate (csol              (nl_soil,numpatch))
     allocate (dksatu            (nl_soil,numpatch))
     allocate (dkdry             (nl_soil,numpatch))

     allocate (htop                      (numpatch))
     allocate (hbot                      (numpatch))

#ifdef PFT_CLASSIFICATION
     CALL allocate_PFTimeInvars
#endif

#ifdef PC_CLASSIFICATION
     CALL allocate_PCTimeInvars
#endif

#ifdef URBAN_MODEL
     CALL allocate_UrbanTimeInvars
#endif

  END SUBROUTINE allocate_TimeInvariants


  SUBROUTINE READ_TimeInvariants(lc_year,dir_restart,casename)
! --------------------------------------------------------------------
! Write out as a restart file [histTimeConst]
! ...............................................
     USE precision
     USE GlobalVars
     USE MOD_PFTimeInvars
     USE MOD_PCTimeInvars
     USE MOD_UrbanTimeInvars
     IMPLICIT NONE

     INTEGER, intent(in) :: lc_year      !year of land cover type data
     CHARACTER(LEN=256), intent(in) :: casename           !casename name
     CHARACTER(LEN=256), intent(in) :: dir_restart

     CHARACTER(len=256) :: cyear         !character for lc_year
     CHARACTER(LEN=256) :: fhistTimeConst
     INTEGER :: lhistTimeConst

     ! land cover type year
     write(cyear,'(i4.4)') lc_year

     lhistTimeConst = 100
     fhistTimeConst = trim(dir_restart)//trim(casename)//'-'//'rstTimeConst'//'.lc'//trim(cyear)
     open(unit=lhistTimeConst,file=trim(fhistTimeConst),status='unknown',&
                              form='unformatted',action='read')

     read (lhistTimeConst)  &!
           patch2lon,       &! longitude index for each patch point
           patch2lat,       &! latitude index for each patch point
           patchclass,      &! index of land cover type of the patches at the fraction > 0
           patchtype,       &! land water TYPE
           grid_patch_s,    &! start patch number of grid
           grid_patch_e,    &! end patch number of grid
           gridarea,        &! area of grid the patch located in
           patchfrac         ! subgrid weight for each patch point

     read (lhistTimeConst)  &!
           patchlatr,       &! latitude in radians
           patchlonr,       &! longitude in radians
           gridlatd,        &! latitude in degrees
           gridlond,        &! longitude in degrees

           lakedepth,       &! lake depth
           dz_lake,         &! new lake scheme

           soil_s_v_alb,    &! albedo of visible of the saturated soil
           soil_d_v_alb,    &! albedo of visible of the dry soil
           soil_s_n_alb,    &! albedo of near infrared of the saturated soil
           soil_d_n_alb,    &! albedo of near infrared of the dry soil
           porsl,           &! fraction of soil that is voids [-]
           psi0,            &! minimum soil suction [mm] (NOTE: "-" valued)
           bsw,             &! clapp and hornbereger "b" parameter [-]
           hksati,          &! hydraulic conductivity at saturation [mm h2o/s]
           csol,            &! heat capacity of soil solids [J/(m3 K)]
           dksatu,          &! thermal conductivity of saturated soil [W/m-K]
           dkdry,           &! thermal conductivity for dry soil  [W/(m-K)]

           htop,            &! canopy top height [m]
           hbot,            &! canopy bottom height [m]

     ! CLM TUNABLE constants
           zlnd,            &! roughness length for soil [m]
           zsno,            &! roughness length for snow [m]
           csoilc,          &! drag coefficient for soil under canopy [-]
           dewmx,           &! maximum dew
           wtfact,          &! fraction of model area with high water table
           capr,            &! tuning factor to turn first layer T into surface T
           cnfac,           &! Crank Nicholson factor between 0 and 1
           ssi,             &! irreducible water saturation of snow
           wimp,            &! water impremeable if porosity less than wimp
           pondmx,          &! ponding depth (mm)
           smpmax,          &! wilting point potential in mm
           smpmin,          &! restriction for min of soil poten. (mm)
           trsmx0,          &! max transpiration for moist soil+100% veg.  [mm/s]
           tcrit             ! critical temp. to determine rain or snow

     ! PFT/PC time invariants
#ifdef PFT_CLASSIFICATION
     read (lhistTimeConst)  &!
           pftclass,        &! PFT type
           pftfrac,         &! PFT fractional cover
           patch_pft_s,     &! patch start index of PFT
           patch_pft_e,     &! patch end index of PFT
           pft2patch,       &! projection from PFT to patch
           htop_p,          &! canopy top height [m]
           hbot_p            ! canopy bottom height [m]
#endif

#ifdef PC_CLASSIFICATION
     read (lhistTimeConst)  &!
           patch2pc,        &! projection from patch to PC
           pc2patch,        &! projection from PC to patch
           pcfrac,          &! PC fractional cover
           htop_c,          &! canopy top height [m]
           hbot_c            ! canopy bottom height [m]
#endif

#ifdef URBAN_MODEL
     read (lhistTimeConst)  &!
           urbclass,        &! urban class/density TYPE
           patch2urb,       &! projection from patch to Urban
           urb2patch,       &! projection from Urban to patch
           froof,           &! roof fractional cover [-]
           fgper,           &! impervious fraction to ground area [-]
           flake,           &! lake fraction to ground area [-]
           hroof,           &! average building height [m]
           hwr,             &! average building height to their distance [-]
           z_roof,          &! depth of each roof layer [m]
           z_wall,          &! depth of each wall layer [m]
           dz_roof,         &! thickness of each roof layer [m]
           dz_wall,         &! thickness of each wall layer [m]
           alb_roof,        &! albedo of roof [-]
           alb_wall,        &! albedo of walls [-]
           alb_gimp,        &! albedo of impervious [-]
           alb_gper,        &! albedo of pervious [-]
           em_roof,         &! emissivity of roof [-]
           em_wall,         &! emissivity of walls [-]
           em_gimp,         &! emissivity of impervious [-]
           em_gper,         &! emissivity of pervious [-]
           cv_roof,         &! heat capacity of roof [J/(m2 K)]
           cv_wall,         &! heat capacity of wall [J/(m2 K)]
           cv_gimp,         &! heat capacity of impervious [J/(m2 K)]
           tk_roof,         &! thermal conductivity of roof [W/m-K]
           tk_wall,         &! thermal conductivity of wall [W/m-K]
           tk_gimp,         &! thermal conductivity of impervious [W/m-K]
           t_roommax,       &! maximum temperature of inner room [K]
           t_roommin         ! minimum temperature of inner room [K]
#ifdef USE_LUCY
     read (lhistTimeConst)  &!
           popcell,         &! population density
           vehicle,         &! vehicle numbers per thousand people
           week_holiday,    &! week holidays
           weh_prof,        &! Diurnal vehicle heat profile of weekend
           wdh_prof,        &! Diurnal vehicle heat profile of weekday
           hum_prof,        &! Diurnal metabolic heat profile
           fix_holiday       ! Fixed public holidays, holiday(0) or workday(1)
#endif
#endif

     close(lhistTimeConst)

  END SUBROUTINE READ_TimeInvariants


  SUBROUTINE WRITE_TimeInvariants(lc_year,dir_restart,casename)
! --------------------------------------------------------------------
! Write out as a restart file [histTimeConst]
! ...............................................
     USE precision
     USE GlobalVars
     USE MOD_PFTimeInvars
     USE MOD_PCTimeInvars
     USE MOD_UrbanTimeInvars
     IMPLICIT NONE

     INTEGER, intent(in) :: lc_year      !year of land cover type data
     CHARACTER(LEN=256), intent(in) :: casename           !casename name
     CHARACTER(LEN=256), intent(in) :: dir_restart

     CHARACTER(len=256) :: cyear         !character for lc_year
     CHARACTER(LEN=256) :: fhistTimeConst
     INTEGER :: lhistTimeConst

     ! land cover type year
     write(cyear,'(i4.4)') lc_year

     lhistTimeConst = 100
     fhistTimeConst = trim(dir_restart)//trim(casename)//'-'//'rstTimeConst'//'.lc'//trim(cyear)
     open(unit=lhistTimeConst,file=trim(fhistTimeConst),status='unknown',&
                              form='unformatted',action='write')

     write(lhistTimeConst)  &!
           patch2lon,       &! longitude index for each patch point
           patch2lat,       &! latitude index for each patch point
           patchclass,      &! index of land cover type of the patches at the fraction > 0
           patchtype,       &! land water TYPE
           grid_patch_s,    &! start patch number of grid
           grid_patch_e,    &! end patch number of grid
           gridarea,        &! area of grid the patch located in
           patchfrac         ! subgrid weight for each patch point

     write(lhistTimeConst)  &!
           patchlatr,       &! patch latitude in radians
           patchlonr,       &! patch longitude in radians
           gridlatd,        &! grid latitude in degrees
           gridlond,        &! grid longitude in degrees

     ! Soil and plant parameters OF CLM
           lakedepth,       &! lake depth
           dz_lake,         &! new lake scheme

           soil_s_v_alb,    &! albedo of visible of the saturated soil
           soil_d_v_alb,    &! albedo of visible of the dry soil
           soil_s_n_alb,    &! albedo of near infrared of the saturated soil
           soil_d_n_alb,    &! albedo of near infrared of the dry soil
           porsl,           &! fraction of soil that is voids [-]
           psi0,            &! minimum soil suction [mm] (NOTE: "-" valued)
           bsw,             &! clapp and hornbereger "b" parameter [-]
           hksati,          &! hydraulic conductivity at saturation [mm h2o/s]
           csol,            &! heat capacity of soil solids [J/(m3 K)]
           dksatu,          &! thermal conductivity of saturated soil [W/m-K]
           dkdry,           &! thermal conductivity for dry soil  [W/(m-K)]

           htop,            &! canopy top height [m]
           hbot,            &! canopy bottom height [m]

     ! CLM TUNABLE constants
           zlnd,            &! roughness length for soil [m]
           zsno,            &! roughness length for snow [m]
           csoilc,          &! drag coefficient for soil under canopy [-]
           dewmx,           &! maximum dew
           wtfact,          &! fraction of model area with high water table
           capr,            &! tuning factor to turn first layer T into surface T
           cnfac,           &! Crank Nicholson factor between 0 and 1
           ssi,             &! irreducible water saturation of snow
           wimp,            &! water impremeable if porosity less than wimp
           pondmx,          &! ponding depth (mm)
           smpmax,          &! wilting point potential in mm
           smpmin,          &! restriction for min of soil poten. (mm)
           trsmx0,          &! max transpiration for moist soil+100% veg.  [mm/s]
           tcrit             ! critical temp. to determine rain or snow

     ! PFT/PC time invariants
#ifdef PFT_CLASSIFICATION
     write(lhistTimeConst)  &!
           pftclass,        &! PFT type
           pftfrac,         &! PFT fractional cover
           patch_pft_s,     &! patch start index of PFT
           patch_pft_e,     &! patch end index of PFT
           pft2patch,       &! projection from PFT to patch
           htop_p,          &! canopy top height [m]
           hbot_p            ! canopy bottom height [m]
#endif

#ifdef PC_CLASSIFICATION
     write(lhistTimeConst)  &!
           patch2pc,        &! projection from patch to PC
           pc2patch,        &! projection from PC to patch
           pcfrac,          &! PC fractional cover
           htop_c,          &! canopy top height [m]
           hbot_c            ! canopy bottom height [m]
#endif

#ifdef URBAN_MODEL
     write(lhistTimeConst)  &!
           urbclass,        &! urban class/density TYPE
           patch2urb,       &! projection from patch to Urban
           urb2patch,       &! projection from Urban to patch
           froof,           &! roof fractional cover [-]
           fgper,           &! impervious fraction to ground area [-]
           flake,           &! lake fraction to ground area [-]
           hroof,           &! average building height [m]
           hwr,             &! average building height to their distance [-]
           z_roof,          &! thickness of roof [m]
           z_wall,          &! thickness of wall [m]
           dz_roof,         &! thickness of each layer [m]
           dz_wall,         &! thickness of each layer [m]
           alb_roof,        &! albedo of roof [-]
           alb_wall,        &! albedo of walls [-]
           alb_gimp,        &! albedo of impervious [-]
           alb_gper,        &! albedo of pervious [-]
           em_roof,         &! emissivity of roof [-]
           em_wall,         &! emissivity of walls [-]
           em_gimp,         &! emissivity of impervious [-]
           em_gper,         &! emissivity of pervious [-]
           cv_roof,         &! heat capacity of roof [J/(m2 K)]
           cv_wall,         &! heat capacity of wall [J/(m2 K)]
           cv_gimp,         &! heat capacity of impervious [J/(m2 K)]
           tk_roof,         &! thermal conductivity of roof [W/m-K]
           tk_wall,         &! thermal conductivity of wall [W/m-K]
           tk_gimp,         &! thermal conductivity of impervious [W/m-K]
           t_roommax,       &! maximum temperature of inner room [K]
           t_roommin         ! minimum temperature of inner room [K]
#ifdef USE_LUCY
     write(lhistTimeConst)  &!
           popcell,         &! population density
           vehicle,         &! vehicle numbers per thousand people
           week_holiday,    &! week holidays
           weh_prof,        &! Diurnal traffic flow profile of weekend
           wdh_prof,        &! Diurnal traffic flow profile of weekday
           hum_prof,        &! Diurnal metabolic heat profile
           fix_holiday       ! Fixed public holidays, holiday(0) or workday(1)
#endif
#endif
     close(lhistTimeConst)

  END SUBROUTINE WRITE_TimeInvariants


  SUBROUTINE deallocate_TimeInvariants
! --------------------------------------------------
! Deallocates memory for CLM 1d [numpatch] variables
! --------------------------------------------------
     USE MOD_PFTimeInvars
     USE MOD_PCTimeInvars
     USE MOD_UrbanTimeInvars

     deallocate (patch2lon    )
     deallocate (patch2lat    )
     deallocate (patchclass   )
     deallocate (patchtype    )
     deallocate (grid_patch_s )
     deallocate (grid_patch_e )
     deallocate (gridarea     )
     deallocate (patchfrac    )

     deallocate (patchlatr    )
     deallocate (patchlonr    )
     deallocate (gridlatd     )
     deallocate (gridlond     )

     deallocate (lakedepth    )
     deallocate (dz_lake      )

     deallocate (soil_s_v_alb )
     deallocate (soil_d_v_alb )
     deallocate (soil_s_n_alb )
     deallocate (soil_d_n_alb )
     deallocate (porsl        )
     deallocate (psi0         )
     deallocate (bsw          )
     deallocate (hksati       )
     deallocate (csol         )
     deallocate (dksatu       )
     deallocate (dkdry        )

     deallocate (htop         )
     deallocate (hbot         )

#ifdef PFT_CLASSIFICATION
     CALL deallocate_PFTimeInvars
#endif

#ifdef PC_CLASSIFICATION
     CALL deallocate_PCTimeInvars
#endif

#ifdef URBAN_MODEL
     CALL deallocate_UrbanTimeInvars
#endif

  END SUBROUTINE deallocate_TimeInvariants

END MODULE MOD_TimeInvariants
! ---------- EOP ------------
