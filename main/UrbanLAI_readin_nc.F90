#include <define.h>

SUBROUTINE UrbanLAI_readin_nc (year, month, dir_srfdata, nam_urbdata)

! ===========================================================
! Read in urban LAI, SAI and urban tree cover data
! ===========================================================

      USE precision
      USE GlobalVars
      USE LC_Const
      USE MOD_TimeVariables
      USE MOD_TimeInvariants
      USE MOD_UrbanTimeInvars
      USE ncio
      USE omp_lib

      IMPLICIT NONE

      INTEGER, intent(in) :: year
      INTEGER, intent(in) :: month
      CHARACTER(LEN=256), intent(in) :: dir_srfdata
      CHARACTER(LEN=256), intent(in) :: nam_urbdata

      CHARACTER(LEN=256) :: lndname
      CHARACTER(len=256) :: cyear
      INTEGER :: ncid
      INTEGER :: urbantreelai_vid, urbantreesai_vid
      INTEGER :: i, j, t, u, npatch

      REAL(r8), allocatable :: urbantreelai(:,:,:)
      REAL(r8), allocatable :: urbantreesai(:,:,:)

! READ in Leaf area index and stem area index
      write(cyear,'(i4.4)') year

      allocate ( urbantreelai(1:lon_points,1:lat_points,N_URB) )
      allocate ( urbantreesai(1:lon_points,1:lat_points,N_URB) )
#ifdef USE_LCZ
      !TODO@wenzong: change to input parameter
      lndname = '/hard/dongwz/LCZS/global/global/colm_LCZ_data_modis_v1_'//trim(cyear)//'.nc' !'/'//trim(nam_urbdata)
      print*,trim(lndname)

      !TODO@wenzong: combine the same code lines below
      CALL nccheck( nf90_open(trim(lndname), nf90_nowrite, ncid) )
      CALL nccheck( nf90_inq_varid(ncid, "LCZ_TREE_LAI", urbantreelai_vid) )
      CALL nccheck( nf90_inq_varid(ncid, "LCZ_TREE_SAI", urbantreesai_vid) )
      CALL nccheck( nf90_get_var(ncid, urbantreelai_vid, urbantreelai, &
           start=(/1,1,1,month/), count=(/lon_points,lat_points,N_URB,1/)) )
      CALL nccheck( nf90_get_var(ncid, urbantreesai_vid, urbantreesai, &
           start=(/1,1,1,month/), count=(/lon_points,lat_points,N_URB,1/)) )
#else
      lndname = trim(dir_srfdata)//trim(cyear)//'/'//trim(nam_urbdata)
      print*,trim(lndname)
      CALL nccheck( nf90_open(trim(lndname), nf90_nowrite, ncid) )

      CALL nccheck( nf90_inq_varid(ncid, "URBAN_TREE_LAI", urbantreelai_vid) )
      CALL nccheck( nf90_inq_varid(ncid, "URBAN_TREE_SAI", urbantreesai_vid) )
      CALL nccheck( nf90_get_var(ncid, urbantreelai_vid, urbantreelai, &
           start=(/1,1,1,month/), count=(/lon_points,lat_points,N_URB,1/)) )
      CALL nccheck( nf90_get_var(ncid, urbantreesai_vid, urbantreesai, &
           start=(/1,1,1,month/), count=(/lon_points,lat_points,N_URB,1/)) )
#endif

#ifdef OPENMP
!$OMP PARALLEL DO NUM_THREADS(OPENMP) &
!$OMP PRIVATE(i,j,t,u,npatch)
#endif
      DO u = 1, numurban

         npatch = urb2patch(u)
         i = patch2lon(npatch)
         j = patch2lat(npatch)
         t = urbclass(u)

         tlai(npatch)  = urbantreelai(i,j,t) !leaf area index
         tsai(npatch)  = urbantreesai(i,j,t) !stem are index
         green(npatch) = 1.                  !fraction of green leaf

      ENDDO
#ifdef OPENMP
!$OMP END PARALLEL DO
#endif

      deallocate ( urbantreelai )
      deallocate ( urbantreesai )

      CALL nccheck( nf90_close(ncid) )

END SUBROUTINE UrbanLAI_readin_nc
