#include <define.h>

MODULE MOD_UrbanTimeInvars

! -------------------------------
! Created by Hua Yuan, 12/2020
! -------------------------------

   USE precision
   IMPLICIT NONE
   SAVE

   INTEGER , allocatable :: urbclass    (:)  !urban TYPE
   INTEGER , allocatable :: patch2urb   (:)  !projection from patch to Urban
   INTEGER , allocatable :: urb2patch   (:)  !projection from Urban to patch

   REAL(r8), allocatable :: popcell(:)       !pop density
   REAL(r8), allocatable :: vehicle(:,:)     !vehicle numbers per thousand people
   REAL(r8), allocatable :: week_holiday(:,:)!week holidays
   REAL(r8), allocatable :: weh_prof(:,:)    !Diurnal traffic flow profile of weekend
   REAL(r8), allocatable :: wdh_prof(:,:)    !Diurnal traffic flow profile of weekday
   REAL(r8), allocatable :: hum_prof(:,:)    !Diurnal metabolic heat profile
   REAL(r8), allocatable :: fix_holiday(:,:) !Fixed public holidays, holiday(0) or workday(1)

   ! 城市形态结构参数
   REAL(r8), allocatable :: froof       (:)  !roof fractional cover [-]
   REAL(r8), allocatable :: fgper       (:)  !impervious fraction to ground area [-]
   REAL(r8), allocatable :: flake       (:)  !lake fraction to ground area [-]
   REAL(r8), allocatable :: hroof       (:)  !average building height [m]
   REAL(r8), allocatable :: hwr         (:)  !average building height to their distance [-]

   REAL(r8), allocatable :: z_roof    (:,:)  !depth of each roof layer [m]
   REAL(r8), allocatable :: z_wall    (:,:)  !depth of each wall layer [m]
   REAL(r8), allocatable :: dz_roof   (:,:)  !thickness of each roof layer [m]
   REAL(r8), allocatable :: dz_wall   (:,:)  !thickness of each wall layer [m]

   ! albedo
   REAL(r8), allocatable :: alb_roof(:,:,:)  !albedo of roof [-]
   REAL(r8), allocatable :: alb_wall(:,:,:)  !albedo of walls [-]
   REAL(r8), allocatable :: alb_gimp(:,:,:)  !albedo of impervious [-]
   REAL(r8), allocatable :: alb_gper(:,:,:)  !albedo of pervious [-]

   ! emissivity
   REAL(r8), allocatable :: em_roof     (:)  !emissivity of roof [-]
   REAL(r8), allocatable :: em_wall     (:)  !emissivity of walls [-]
   REAL(r8), allocatable :: em_gimp     (:)  !emissivity of impervious [-]
   REAL(r8), allocatable :: em_gper     (:)  !emissivity of pervious [-]

   ! thermal pars of roof, wall, impervious
   REAL(r8), allocatable :: cv_roof   (:,:)  !heat capacity of roof [J/(m2 K)]
   REAL(r8), allocatable :: cv_wall   (:,:)  !heat capacity of wall [J/(m2 K)]
   REAL(r8), allocatable :: cv_gimp   (:,:)  !heat capacity of impervious [J/(m2 K)]

   REAL(r8), allocatable :: tk_roof   (:,:)  !thermal conductivity of roof [W/m-K]
   REAL(r8), allocatable :: tk_wall   (:,:)  !thermal conductivity of wall [W/m-K]
   REAL(r8), allocatable :: tk_gimp   (:,:)  !thermal conductivity of impervious [W/m-K]

   ! room maximum and minimum temperature
   REAL(r8), allocatable :: t_roommax   (:)  !maximum temperature of inner room [K]
   REAL(r8), allocatable :: t_roommin   (:)  !minimum temperature of inner room [K]

! PUBLIC MEMBER FUNCTIONS:
   PUBLIC :: allocate_UrbanTimeInvars
   PUBLIC :: deallocate_UrbanTimeInvars

! PRIVATE MEMBER FUNCTIONS:

!-----------------------------------------------------------------------

CONTAINS

!-----------------------------------------------------------------------

   SUBROUTINE allocate_UrbanTimeInvars ()
! ------------------------------------------------------
! Allocates memory for CLM 1d [numurban] variants
! ------------------------------------------------------
      USE precision
      USE GlobalVars
      IMPLICIT NONE



      allocate (urbclass             (numurban))
      allocate (patch2urb            (numpatch))
      allocate (urb2patch            (numurban))

      allocate (froof                (numurban))
      allocate (fgper                (numurban))
      allocate (flake                (numurban))
      allocate (hroof                (numurban))
      allocate (hwr                  (numurban))

      allocate (alb_roof         (2,2,numurban))
      allocate (alb_wall         (2,2,numurban))
      allocate (alb_gimp         (2,2,numurban))
      allocate (alb_gper         (2,2,numurban))

      allocate (em_roof              (numurban))
      allocate (em_wall              (numurban))
      allocate (em_gimp              (numurban))
      allocate (em_gper              (numurban))

      allocate (z_roof     (1:nl_roof,numurban))
      allocate (z_wall     (1:nl_wall,numurban))
      allocate (dz_roof    (1:nl_roof,numurban))
      allocate (dz_wall    (1:nl_wall,numurban))

      allocate (cv_roof    (1:nl_roof,numurban))
      allocate (cv_wall    (1:nl_wall,numurban))
      allocate (cv_gimp    (1:nl_soil,numurban))
      allocate (tk_roof    (1:nl_roof,numurban))
      allocate (tk_wall    (1:nl_wall,numurban))
      allocate (tk_gimp    (1:nl_soil,numurban))

      allocate (t_roommax            (numurban))
      allocate (t_roommin            (numurban))
      allocate (popcell              (numurban))

      allocate (vehicle          (numurban,3  ))
      allocate (week_holiday     (numurban,7  ))
      allocate (weh_prof         (numurban,24 ))
      allocate (wdh_prof         (numurban,24 ))
      allocate (hum_prof         (numurban,24 ))
      allocate (fix_holiday      (numurban,365))

   END SUBROUTINE allocate_UrbanTimeInvars

   SUBROUTINE deallocate_UrbanTimeInvars

      deallocate (urbclass  )
      deallocate (patch2urb )
      deallocate (urb2patch )

      deallocate (froof     )
      deallocate (fgper     )
      deallocate (flake     )
      deallocate (hroof     )
      deallocate (hwr       )

      deallocate (alb_roof  )
      deallocate (alb_wall  )
      deallocate (alb_gimp  )
      deallocate (alb_gper  )

      deallocate (em_roof   )
      deallocate (em_wall   )
      deallocate (em_gimp   )
      deallocate (em_gper   )

      deallocate (z_roof    )
      deallocate (z_wall    )
      deallocate (dz_roof   )
      deallocate (dz_wall   )

      deallocate (cv_roof   )
      deallocate (cv_wall   )
      deallocate (cv_gimp   )
      deallocate (tk_roof   )
      deallocate (tk_wall   )
      deallocate (tk_gimp   )

      deallocate (t_roommax )
      deallocate (t_roommin )

      deallocate (popcell      )
      deallocate (vehicle      )
      deallocate (week_holiday )
      deallocate (weh_prof     )
      deallocate (wdh_prof     )
      deallocate (hum_prof     )
      deallocate (fix_holiday  )
   END SUBROUTINE deallocate_UrbanTimeInvars

END MODULE MOD_UrbanTimeInvars
! ---------- EOP ------------
