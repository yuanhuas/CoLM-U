
#include <define.h>

MODULE user_specified_forcing

! ------------------------------------------------------------
! MODULE NANE:
!     User specified forcing for:
!          PRIMCETON GSWP2 QIAN CRUNCEP GSWP3 POINT
!
! PURPOSE :
!     Read PRINCETON/GSWP2/QIAN/CRUNCEP/GSWP3/POINT forcing data
!
!     PLEASE modify the following codes when specified forcing used
!     metpreprocess modified by siguang & weinan for forc_q calibration
! ------------------------------------------------------------

   USE precision
   USE PhysicalConstants
   USE omp_lib
   IMPLICIT NONE

#if(defined USE_ERA5LAND_DATA)
 ! ------------------------------------------------------------
 ! parameter setting
 ! ------------------------------------------------------------
   integer, parameter :: NVAR    = 8              ! variable number of forcing data
   integer, parameter :: nlats   = 1800           ! number of latitudes
   integer, parameter :: nlons   = 3600           ! number of longitudes
   integer, parameter :: startyr = 1950           ! start year of forcing data
   integer, parameter :: startmo = 1              ! start month of forcing data
   integer, parameter :: endyr   = 2021           ! end year of forcing data
   integer, parameter :: endmo   = 12             ! end month of forcing data
   integer, parameter :: dtime(NVAR)  = (/ &      ! temporal resolution
      3600, 3600, 3600, 3600, 3600, 3600, 3600, 3600/)
   integer, parameter :: offset(NVAR) = (/ &      ! time offset (seconds)
      1800, 1800, 1800, 1800, 1800, 1800, 0, 1800/)    ! ..
   integer, parameter :: nlands  = 1              ! land grid number in 1d

   logical, parameter :: leapyear = .true.        ! leapyear calendar
   logical, parameter :: data2d   = .true.        ! data in 2 dimension (lon, lat)
   logical, parameter :: hightdim = .false.       ! have "z" dimension
   logical, parameter :: dim2d    = .false.       ! lat/lon value in 2 dimension (lon, lat)
   logical, parameter :: latrev   = .false.       ! need to reverse latitudes
   logical, parameter :: lonadj   = .true.        ! need to adjust longitude, 0~360 -> -180~180

   character(len=256), parameter :: latname = 'latitude'  ! dimension name of latitude
   character(len=256), parameter :: lonname = 'longitude'  ! dimension name of longitude

 ! file grouped by year/month
   character(len=256), parameter :: groupby = 'month'

 ! prefix of forcing data file
   character(len=256), parameter :: fprefix(NVAR) = [character(len=256) :: &
      '2m_temperature/ERA5LAND_', &
      'specific_humidity/ERA5LAND_', &
      'surface_pressure/ERA5LAND_', &
      'Precipitation_m_hr/ERA5LAND_', &
      '10m_u_component_of_wind/ERA5LAND_', &
      '10m_v_component_of_wind/ERA5LAND_', &
      'surface_solar_radiation_downwards_w_m2/ERA5LAND_', &
      'surface_thermal_radiation_downwards_w_m2/ERA5LAND_']

 ! suffix of forcing data file
   character(len=256), parameter :: suffix(NVAR) = [character(len=256) :: &
      '_2m_temperature.nc', &
      '_specific_humidity.nc', &
      '_surface_pressure.nc', &
      '_total_precipitation_m_hr.nc', &
      '_10m_u_component_of_wind.nc', &
      '_10m_v_component_of_wind.nc', &
      '_surface_solar_radiation_downwards_w_m2.nc', &
      '_surface_thermal_radiation_downwards_w_m2.nc']

 ! variable name of forcing data file
   character(len=256), parameter :: vname(NVAR) = [character(len=256) :: &
      't2m', 'Q', 'sp', 'tp', 'u10', 'v10', 'ssrd', 'strd']

 ! interpolation method
   character(len=256), parameter :: tintalgo(NVAR) = [character(len=256) :: &
      'linear', 'linear', 'linear', 'nearest', 'linear', 'linear', 'coszen', 'linear']

   INTERFACE getfilename
      MODULE procedure getfilename
   END INTERFACE

   INTERFACE metpreprocess
      MODULE procedure metpreprocess
   END INTERFACE

   public metpreprocess

CONTAINS

   FUNCTION getfilename(year, month, var_i)

      implicit none
      integer, intent(in) :: year
      integer, intent(in) :: month
      integer, intent(in) :: var_i
      character(len=256)  :: getfilename
      character(len=256)  :: yearstr
      character(len=256)  :: monthstr

      write(yearstr, '(I4.4)') year
      write(monthstr, '(I2.2)') month
      getfilename = '/'//trim(fprefix(var_i))//trim(yearstr)//'_'//trim(monthstr)//trim(suffix(var_i))
      return
   END FUNCTION getfilename

 ! preprocess for forcing data
 ! ------------------------------------------------------------
   SUBROUTINE metpreprocess(forcn)

      implicit none
      real(r8), intent(inout) :: forcn(:,:,:)

      integer  :: i, j
      real(r8) :: es, esdT, qsat_tmp, dqsat_tmpdT

!----------------------------------------------------------------------------
! use polynomials to calculate saturation vapor pressure and derivative with
! respect to temperature: over water when t > 0 c and over ice when t <= 0 c
! required to convert relative humidity to specific humidity
!----------------------------------------------------------------------------
#ifdef OPENMP
!$OMP PARALLEL DO NUM_THREADS(OPENMP) PRIVATE(i,j,es,esdT,qsat_tmp,dqsat_tmpdT)
#endif
      do i = 1, lat_points
         do j = 1, lon_points
            if (forcn(j,i,1) < 0.0) forcn(j,i,1) = 280.0
            if (forcn(j,i,2) < 0.0) forcn(j,i,2) = 0.01
            if (forcn(j,i,3) < 0.0) forcn(j,i,3) = 96000.
            forcn(j,i,4) = forcn(j,i,4)*1000./3600.
            if (forcn(j,i,4) < 0.0)   forcn(j,i,4) = 0.0
            if (forcn(j,i,7) < 0.0)   forcn(j,i,7) = 0.0
            if (forcn(j,i,5) < -300.0)   forcn(j,i,5) = 2.0
            if (forcn(j,i,6) < -300.0)   forcn(j,i,6) = 2.0
            if (abs(forcn(j,i,5)) > 40.0) forcn(j,i,5) = 40.0*forcn(j,i,5)/abs(forcn(j,i,5)) ! 12th grade of Typhoon 32.7-36.9 m/s 
            if (abs(forcn(j,i,6)) > 40.0) forcn(j,i,6) = 40.0*forcn(j,i,6)/abs(forcn(j,i,6))
            if (forcn(j,i,8) < -300.0)   forcn(j,i,8) = 300.0
            call qsadv(forcn(j,i,1),forcn(j,i,3),es,esdT,qsat_tmp,dqsat_tmpdT)
            if (qsat_tmp < forcn(j,i,2)) then
               forcn(j,i,2) = qsat_tmp
            endif
         end do
      end do
#ifdef OPENMP
!$OMP END PARALLEL DO
#endif
   END SUBROUTINE metpreprocess

#endif 

#if (defined USE_PRINCETON_DATA)

 ! parameter setting
 ! ------------------------------------------------------------
   integer, parameter :: NVAR    = 8              ! variable number of forcing data
   integer, parameter :: nlats   = 180            ! number of latitudes
   integer, parameter :: nlons   = 360            ! number of longitudes
   integer, parameter :: startyr = 1948           ! start year of forcing data
   integer, parameter :: startmo = 1              ! start month of forcing data
   integer, parameter :: endyr   = 2006           ! end year of forcing data
   integer, parameter :: endmo   = 12             ! end month of forcing data
   integer, parameter :: dtime(NVAR)  = 10800     ! temporal resolution
   integer, parameter :: offset(NVAR) = 0         ! time offset (seconds)
   integer, parameter :: nlands  = 1              ! land grid number in 1d

   logical, parameter :: leapyear = .true.        ! leapyear calendar
   logical, parameter :: data2d   = .true.        ! data in 2 dimension (lon, lat)
   logical, parameter :: hightdim = .true.        ! have "z" dimension
   logical, parameter :: dim2d    = .false.       ! lat/lon value in 2 dimension (lon, lat)
   logical, parameter :: latrev   = .true.        ! need to reverse latitudes
   logical, parameter :: lonadj   = .true.        ! need to adjust longitude, 0~360 -> -180~180

   character(len=256), parameter :: latname = 'latitude'  ! dimension name of latitude
   character(len=256), parameter :: lonname = 'longitude' ! dimension name of longitude

 ! file grouped by year/month
   character(len=256), parameter :: groupby = 'year'

 ! prefix of forcing data file
   character(len=256), parameter :: fprefix(NVAR) = [character(len=256) :: &
      'tas/tas_3hourly_', 'shum/shum_3hourly_', 'pres/pres_3hourly_', &
      'prcp/prcp_3hourly_', 'NULL', 'wind/wind_3hourly_', &
      'dswrf/dswrf_3hourly_', 'dlwrf/dlwrf_3hourly_']

 ! variable name of forcing data file
   character(len=256), parameter :: vname(NVAR) = [character(len=256) :: &
      'tas', 'shum', 'pres', 'prcp', 'NULL', 'wind', 'dswrf', 'dlwrf']

 ! interpolation method
   character(len=256), parameter :: tintalgo(NVAR) = [character(len=256) :: &
      'linear', 'linear', 'linear', 'nearest', 'NULL', 'linear', 'coszen', 'linear']

   INTERFACE getfilename
      MODULE procedure getfilename
   END INTERFACE

   INTERFACE metpreprocess
      MODULE procedure metpreprocess
   END INTERFACE

   public metpreprocess

CONTAINS

   FUNCTION getfilename(year, month, var_i)

      implicit none
      integer, intent(in) :: year
      integer, intent(in) :: month
      integer, intent(in) :: var_i
      character(len=256)  :: getfilename
      character(len=256)  :: yearstr

      write(yearstr, '(I4.4)') year
      getfilename = '/'//trim(fprefix(var_i))//trim(yearstr)//'-'//trim(yearstr)//'.nc'
      return
   END FUNCTION getfilename

 ! preprocess for forcing data [not applicable yet for PRINCETON]
 ! ------------------------------------------------------------
   SUBROUTINE metpreprocess(forcn)

      implicit none
      real(r8), intent(inout) :: forcn(:,:,:)

      integer  :: i, j
      real(r8) :: es, esdT, qsat_tmp, dqsat_tmpdT

!----------------------------------------------------------------------------
! use polynomials to calculate saturation vapor pressure and derivative with
! respect to temperature: over water when t > 0 c and over ice when t <= 0 c
! required to convert relative humidity to specific humidity
!----------------------------------------------------------------------------
#ifdef OPENMP
!$OMP PARALLEL DO NUM_THREADS(OPENMP) PRIVATE(i,j,es,esdT,qsat_tmp,dqsat_tmpdT)
#endif
      do i = 1, nlats
         do j = 1, nlons
            call qsadv(forcn(j,i,1),forcn(j,i,3),es,esdT,qsat_tmp,dqsat_tmpdT)
            if (qsat_tmp < forcn(j,i,2)) then
               forcn(j,i,2) = qsat_tmp
            endif
         end do
      end do
#ifdef OPENMP
!$OMP END PARALLEL DO
#endif

   END SUBROUTINE metpreprocess

#endif



#if(defined USE_GSWP2_DATA)

 ! parameter setting
 ! ------------------------------------------------------------
   integer, parameter :: NVAR    = 8              ! variable number of forcing data
   integer, parameter :: nlats   = 150            ! number of latitudes
   integer, parameter :: nlons   = 360            ! number of longitudes
   integer, parameter :: startyr = 1982           ! start year of forcing data
   integer, parameter :: startmo = 7              ! start month of forcing data
   integer, parameter :: endyr   = 1995           ! end year of forcing data
   integer, parameter :: endmo   = 12             ! end month of forcing data
   integer, parameter :: dtime(NVAR)  = 10800     ! temporal resolution
   integer, parameter :: offset(NVAR) = 10800     ! time offset (seconds)
   integer, parameter :: nlands  = 15238          ! land grid number in 1d

   logical, parameter :: leapyear = .true.        ! leapyear calendar
   logical, parameter :: data2d   = .false.       ! data in 2 dimension (lon, lat)
   logical, parameter :: hightdim = .false.       ! have "z" dimension
   logical, parameter :: dim2d    = .true.        ! lat/lon value in 2 dimension (lon, lat)
   logical, parameter :: latrev   = .false.       ! need to reverse latitudes
   logical, parameter :: lonadj   = .false.       ! need to adjust longitude, 0~360 -> -180~180

   character(len=256), parameter :: latname = 'nav_lat'  ! dimension name of latitude
   character(len=256), parameter :: lonname = 'nav_lon'  ! dimension name of longitude

 ! file grouped by year/month
   character(len=256), parameter :: groupby = 'month'

 ! prefix of forcing data file
   character(len=256), parameter :: fprefix(NVAR) = [character(len=256) :: &
      'Tair_cru/Tair_cru', 'Qair_cru/Qair_cru', 'PSurf_ecor/PSurf_ecor', &
      'Rainf_gswp/Rainf_gswp', 'Rainf_C_gswp/Rainf_C_gswp', 'Wind_ncep/Wind_ncep', &
      'SWdown_srb/SWdown_srb', 'LWdown_srb/LWdown_srb']

 ! variable name of forcing data file
   character(len=256), parameter :: vname(NVAR) = [character(len=256) :: &
      'Tair', 'Qair', 'PSurf', 'Rainf', 'Rainf_C', 'Wind', 'SWdown', 'LWdown']

 ! interpolation method
   character(len=256), parameter :: tintalgo(NVAR) = [character(len=256) :: &
      'linear', 'linear', 'linear', 'nearest', 'nearest', 'linear', 'coszen', 'linear']

   INTERFACE getfilename
      MODULE procedure getfilename
   END INTERFACE

   INTERFACE metpreprocess
      MODULE procedure metpreprocess
   END INTERFACE

   public metpreprocess

CONTAINS

   FUNCTION getfilename(year, month, var_i)

      implicit none
      integer, intent(in) :: year
      integer, intent(in) :: month
      integer, intent(in) :: var_i
      character(len=256)  :: getfilename
      character(len=256)  :: yearstr
      character(len=256)  :: monthstr

      write(yearstr, '(I4.4)') year
      write(monthstr, '(I2.2)') month
      getfilename = '/'//trim(fprefix(var_i))//trim(yearstr)//trim(monthstr)//'.nc'
      return
   END FUNCTION getfilename

 ! preprocess for forcing data [not applicable yet for GSWP2]
 ! ------------------------------------------------------------
   SUBROUTINE metpreprocess(forcn)

      implicit none
      real(r8), intent(inout) :: forcn(:,:,:)

      integer  :: i, j
      real(r8) :: es, esdT, qsat_tmp, dqsat_tmpdT

!----------------------------------------------------------------------------
! use polynomials to calculate saturation vapor pressure and derivative with
! respect to temperature: over water when t > 0 c and over ice when t <= 0 c
! required to convert relative humidity to specific humidity
!----------------------------------------------------------------------------
#ifdef OPENMP
!$OMP PARALLEL DO NUM_THREADS(OPENMP) PRIVATE(i,j,es,esdT,qsat_tmp,dqsat_tmpdT)
#endif
      do i = 1, nlats
         do j = 1, nlons
            call qsadv(forcn(j,i,1),forcn(j,i,3),es,esdT,qsat_tmp,dqsat_tmpdT)
            if (qsat_tmp < forcn(j,i,2)) then
               forcn(j,i,2) = qsat_tmp
            endif
         end do
      end do
#ifdef OPENMP
!$OMP END PARALLEL DO
#endif

   END SUBROUTINE metpreprocess

#endif



#if(defined USE_QIAN_DATA)

 ! parameter setting
 ! ------------------------------------------------------------
   integer, parameter :: NVAR    = 8              ! variable number of forcing data
   integer, parameter :: nlats   = 94             ! number of latitudes
   integer, parameter :: nlons   = 192            ! number of longitudes
   integer, parameter :: startyr = 1972           ! start year of forcing data       <MARK #2>
   integer, parameter :: startmo = 1              ! start month of forcing data
   integer, parameter :: endyr   = 2004           ! end year of forcing data
   integer, parameter :: endmo   = 12             ! end month of forcing data
   integer, parameter :: dtime(NVAR)  = (/ &      ! temporal resolution
      10800, 10800, 10800, 21600, 0, 10800, 21600, 0/)
   integer, parameter :: offset(NVAR) = (/ &      ! time offset (seconds)
      5400, 5400, 5400, 10800, 0, 5400, 0, 0/)    ! ..
   integer, parameter :: nlands  = 1              ! land grid number in 1d

   logical, parameter :: leapyear = .false.       ! leapyear calendar
   logical, parameter :: data2d   = .true.        ! data in 2 dimension (lon, lat)
   logical, parameter :: hightdim = .false.       ! have "z" dimension
   logical, parameter :: dim2d    = .true.        ! lat/lon value in 2 dimension (lon, lat)
   logical, parameter :: latrev   = .true.        ! need to reverse latitudes
   logical, parameter :: lonadj   = .true.        ! need to adjust longitude, 0~360 -> -180~180

   character(len=256), parameter :: latname = 'LATIXY'  ! dimension name of latitude
   character(len=256), parameter :: lonname = 'LONGXY'  ! dimension name of longitude

 ! file grouped by year/month
   character(len=256), parameter :: groupby = 'month'

 ! prefix of forcing data file
   character(len=256), parameter :: fprefix(NVAR) = [character(len=256) :: &
      'TmpPrsHumWnd3Hrly/clmforc.Qian.c2006.T62.TPQW.', &
      'TmpPrsHumWnd3Hrly/clmforc.Qian.c2006.T62.TPQW.', &
      'TmpPrsHumWnd3Hrly/clmforc.Qian.c2006.T62.TPQW.', &
      'Precip6Hrly/clmforc.Qian.c2006.T62.Prec.', &
      'NULL', &
      'TmpPrsHumWnd3Hrly/clmforc.Qian.c2006.T62.TPQW.', &
      'Solar6Hrly/clmforc.Qian.c2006.T62.Solr.', &
      'NULL']

 ! variable name of forcing data file
   character(len=256), parameter :: vname(NVAR) = [character(len=256) :: &
      'TBOT', 'QBOT', 'PSRF', 'PRECTmms', 'NULL', 'WIND', 'FSDS', 'NULL']

 ! interpolation method
   character(len=256), parameter :: tintalgo(NVAR) = [character(len=256) :: &
      'linear', 'linear', 'linear', 'nearest', 'NULL', 'linear', 'coszen', 'NULL']

   INTERFACE getfilename
      MODULE procedure getfilename
   END INTERFACE

   INTERFACE metpreprocess
      MODULE procedure metpreprocess
   END INTERFACE

   public metpreprocess

CONTAINS

   FUNCTION getfilename(year, month, var_i)

      implicit none
      integer, intent(in) :: year
      integer, intent(in) :: month
      integer, intent(in) :: var_i
      character(len=256)  :: getfilename
      character(len=256)  :: yearstr
      character(len=256)  :: monthstr

      write(yearstr, '(I4.4)') year
      write(monthstr, '(I2.2)') month
      getfilename = '/'//trim(fprefix(var_i))//trim(yearstr)//'-'//trim(monthstr)//'.nc'
      return
   END FUNCTION getfilename

 ! preprocess for forcing data: calculate LW
 ! ------------------------------------------------------------
   SUBROUTINE metpreprocess(forcn)

      implicit none
      real(r8), intent(inout) :: forcn(:,:,:)

      real(r8) :: e, ea
      integer  :: i, j
      real(r8) :: es, esdT, qsat_tmp, dqsat_tmpdT

!----------------------------------------------------------------------------
! use polynomials to calculate saturation vapor pressure and derivative with
! respect to temperature: over water when t > 0 c and over ice when t <= 0 c
! required to convert relative humidity to specific humidity
!----------------------------------------------------------------------------
#ifdef OPENMP
!$OMP PARALLEL DO NUM_THREADS(OPENMP) &
!$OMP PRIVATE(i,j,e,ea,es,esdT,qsat_tmp,dqsat_tmpdT)
#endif
      do i = 1, nlats
         do j = 1, nlons
            call qsadv(forcn(j,i,1),forcn(j,i,3),es,esdT,qsat_tmp,dqsat_tmpdT)
            if (qsat_tmp < forcn(j,i,2)) then
               forcn(j,i,2) = qsat_tmp
            endif

            e  = forcn(j,i,3) * forcn(j,i,2) / (0.622_R8 + 0.378_R8 * forcn(j,i,2))
            ea = 0.70_R8 + 5.95e-05_R8 * 0.01_R8 * e * exp(1500.0_R8/forcn(j,i,1))
            forcn(j,i,8) = ea * stefnc * forcn(j,i,1)**4
         end do
      end do
#ifdef OPENMP
!$OMP END PARALLEL DO
#endif

   END SUBROUTINE metpreprocess

#endif



#if(defined USE_CRUNCEP_DATA)

 ! parameter setting
 ! ------------------------------------------------------------
   integer, parameter :: NVAR    = 8              ! variable number of forcing data
   integer, parameter :: nlats   = 360            ! number of latitudes
   integer, parameter :: nlons   = 720            ! number of longitudes
   integer, parameter :: startyr = 1901           ! start year of forcing data        <MARK #1>
   integer, parameter :: startmo = 1              ! start month of forcing data
   integer, parameter :: endyr   = 2016           ! end year of forcing data
   integer, parameter :: endmo   = 12             ! end month of forcing data
   integer, parameter :: dtime(NVAR)  = (/ &      ! temporal resolution
      21600, 21600, 21600, 21600, 0, 21600, 21600, 21600/)
   integer, parameter :: offset(NVAR) = (/ &      ! time offset (seconds)
      10800, 10800, 10800, 10800, 0, 10800,     0, 10800/)    ! ..
   integer, parameter :: nlands  = 1              ! land grid number in 1d

   logical, parameter :: leapyear = .false.       ! leapyear calendar
   logical, parameter :: data2d   = .true.        ! data in 2 dimension (lon, lat)
   logical, parameter :: hightdim = .false.       ! have "z" dimension
   logical, parameter :: dim2d    = .true.        ! lat/lon value in 2 dimension (lon, lat)
   logical, parameter :: latrev   = .true.        ! need to reverse latitudes
   logical, parameter :: lonadj   = .true.        ! need to adjust longitude, 0~360 -> -180~180

   character(len=256), parameter :: latname = 'LATIXY'  ! dimension name of latitude
   character(len=256), parameter :: lonname = 'LONGXY'  ! dimension name of longitude

 ! file grouped by year/month
   character(len=256), parameter :: groupby = 'month'

 ! prefix of forcing data file
   character(len=256), parameter :: fprefix(NVAR) = [character(len=256) :: &
      'TPHWL6Hrly/clmforc.cruncep.V7.c2016.0.5d.TPQWL.', &
      'TPHWL6Hrly/clmforc.cruncep.V7.c2016.0.5d.TPQWL.', &
      'TPHWL6Hrly/clmforc.cruncep.V7.c2016.0.5d.TPQWL.', &
      'Precip6Hrly/clmforc.cruncep.V7.c2016.0.5d.Prec.', &
      'NULL', &
      'TPHWL6Hrly/clmforc.cruncep.V7.c2016.0.5d.TPQWL.', &
      'Solar6Hrly/clmforc.cruncep.V7.c2016.0.5d.Solr.', &
      'TPHWL6Hrly/clmforc.cruncep.V7.c2016.0.5d.TPQWL.']

 ! variable name of forcing data file
   character(len=256), parameter :: vname(NVAR) = [character(len=256) :: &
      'TBOT', 'QBOT', 'PSRF', 'PRECTmms', 'NULL', 'WIND', 'FSDS', 'FLDS']

 ! interpolation method
   character(len=256), parameter :: tintalgo(NVAR) = [character(len=256) :: &
      'linear', 'linear', 'linear', 'nearest', 'NULL', 'linear', 'coszen', 'linear']

   INTERFACE getfilename
      MODULE procedure getfilename
   END INTERFACE

   INTERFACE metpreprocess
      MODULE procedure metpreprocess
   END INTERFACE

   public metpreprocess

CONTAINS

   FUNCTION getfilename(year, month, var_i)

      implicit none
      integer, intent(in) :: year
      integer, intent(in) :: month
      integer, intent(in) :: var_i
      character(len=256)  :: getfilename
      character(len=256)  :: yearstr
      character(len=256)  :: monthstr

      write(yearstr, '(I4.4)') year
      write(monthstr, '(I2.2)') month
      getfilename = '/'//trim(fprefix(var_i))//trim(yearstr)//'-'//trim(monthstr)//'.nc'
      return
   END FUNCTION getfilename

 ! preprocess for forcing data
 ! ------------------------------------------------------------
   SUBROUTINE metpreprocess(forcn)

      implicit none
      real(r8), intent(inout) :: forcn(:,:,:)

      integer  :: i, j
      real(r8) :: es, esdT, qsat_tmp, dqsat_tmpdT

!----------------------------------------------------------------------------
! use polynomials to calculate saturation vapor pressure and derivative with
! respect to temperature: over water when t > 0 c and over ice when t <= 0 c
! required to convert relative humidity to specific humidity
!----------------------------------------------------------------------------
#ifdef OPENMP
!$OMP PARALLEL DO NUM_THREADS(OPENMP) PRIVATE(i,j,es,esdT,qsat_tmp,dqsat_tmpdT)
#endif
      do i = 1, nlats
         do j = 1, nlons
            call qsadv(forcn(j,i,1),forcn(j,i,3),es,esdT,qsat_tmp,dqsat_tmpdT)
            if (qsat_tmp < forcn(j,i,2)) then
               forcn(j,i,2) = qsat_tmp
            endif
         end do
      end do
#ifdef OPENMP
!$OMP END PARALLEL DO
#endif

   END SUBROUTINE metpreprocess

#endif



#if(defined USE_GSWP3_DATA)

 ! parameter setting
 ! ------------------------------------------------------------
   integer, parameter :: NVAR    = 8              ! variable number of forcing data
   integer, parameter :: nlats   = 360            ! number of latitudes
   integer, parameter :: nlons   = 720            ! number of longitudes
   integer, parameter :: startyr = 1901           ! start year of forcing data
   integer, parameter :: startmo = 1              ! start month of forcing data
   integer, parameter :: endyr   = 2014           ! end year of forcing data
   integer, parameter :: endmo   = 12             ! end month of forcing data
   integer, parameter :: dtime(NVAR)  = (/ &      ! temporal resolution
      10800, 10800, 10800, 10800, 0, 10800, 10800, 10800/)
   integer, parameter :: offset(NVAR) = (/ &      ! time offset (seconds)
       5400,  5400,  5400,  5400, 0,  5400,     0,  5400/)    ! ..
   integer, parameter :: nlands  = 1              ! land grid number in 1d

   logical, parameter :: leapyear = .false.       ! leapyear calendar
   logical, parameter :: data2d   = .true.        ! data in 2 dimension (lon, lat)
   logical, parameter :: hightdim = .false.       ! have "z" dimension
   logical, parameter :: dim2d    = .true.        ! lat/lon value in 2 dimension (lon, lat)
   logical, parameter :: latrev   = .true.        ! need to reverse latitudes
   logical, parameter :: lonadj   = .true.        ! need to adjust longitude, 0~360 -> -180~180

   character(len=256), parameter :: latname = 'LATIXY'   ! dimension name of latitude
   character(len=256), parameter :: lonname = 'LONGXY'   ! dimension name of longitude

 ! file grouped by year/month
   character(len=256), parameter :: groupby = 'month'

 ! prefix of forcing data file
   character(len=256), parameter :: fprefix(NVAR) = [character(len=256) :: &
      'TPHWL/clmforc.GSWP3.c2011.0.5x0.5.TPQWL.', &
      'TPHWL/clmforc.GSWP3.c2011.0.5x0.5.TPQWL.', &
      'TPHWL/clmforc.GSWP3.c2011.0.5x0.5.TPQWL.', &
      'Precip/clmforc.GSWP3.c2011.0.5x0.5.Prec.', &
      'NULL', &
      'TPHWL/clmforc.GSWP3.c2011.0.5x0.5.TPQWL.', &
      'Solar/clmforc.GSWP3.c2011.0.5x0.5.Solr.',  &
      'TPHWL/clmforc.GSWP3.c2011.0.5x0.5.TPQWL.']

 ! variable name of forcing data file
   character(len=256), parameter :: vname(NVAR) = [character(len=256) :: &
      'TBOT', 'QBOT', 'PSRF', 'PRECTmms', 'NULL', 'WIND', 'FSDS', 'FLDS']

 ! interpolation method
   character(len=256), parameter :: tintalgo(NVAR) = [character(len=256) :: &
      'linear', 'linear', 'linear', 'nearest', 'NULL', 'linear', 'coszen', 'linear']

   INTERFACE getfilename
      MODULE procedure getfilename
   END INTERFACE

   INTERFACE metpreprocess
      MODULE procedure metpreprocess
   END INTERFACE

   public metpreprocess

CONTAINS

   FUNCTION getfilename(year, month, var_i)

      implicit none
      integer, intent(in) :: year
      integer, intent(in) :: month
      integer, intent(in) :: var_i
      character(len=256)  :: getfilename
      character(len=256)  :: yearstr
      character(len=256)  :: monthstr

      write(yearstr, '(I4.4)') year
      write(monthstr, '(I2.2)') month
      getfilename = '/'//trim(fprefix(var_i))//trim(yearstr)//'-'//trim(monthstr)//'.nc'
      return
   END FUNCTION getfilename

 ! preprocess for forcing data
 ! ------------------------------------------------------------
   SUBROUTINE metpreprocess(forcn)

      implicit none
      real(r8), intent(inout) :: forcn(:,:,:)

      integer  :: i, j
      real(r8) :: es, esdT, qsat_tmp, dqsat_tmpdT

!----------------------------------------------------------------------------
! use polynomials to calculate saturation vapor pressure and derivative with
! respect to temperature: over water when t > 0 c and over ice when t <= 0 c
! required to convert relative humidity to specific humidity
!----------------------------------------------------------------------------
#ifdef OPENMP
!$OMP PARALLEL DO NUM_THREADS(OPENMP) PRIVATE(i,j,es,esdT,qsat_tmp,dqsat_tmpdT)
#endif
      do i = 1, nlats
         do j = 1, nlons
            if (forcn(j,i,1) < 212.0) forcn(j,i,1) = 212.0
            if (forcn(j,i,4) < 0.0)   forcn(j,i,4) = 0.0
            call qsadv(forcn(j,i,1),forcn(j,i,3),es,esdT,qsat_tmp,dqsat_tmpdT)
            if (qsat_tmp < forcn(j,i,2)) then
               forcn(j,i,2) = qsat_tmp
            endif
         end do
      end do
#ifdef OPENMP
!$OMP END PARALLEL DO
#endif

   END SUBROUTINE metpreprocess

#endif



#if(defined USE_POINT_DATA)

 ! parameter setting
 ! ------------------------------------------------------------
   integer, parameter :: NVAR    = 8              ! variable number of forcing data
 ! not applied for POINT
   integer, parameter :: nlats   = 2              ! number of latitudes
   integer, parameter :: nlons   = 2              ! number of longitudes
   integer, parameter :: startyr = 1994           ! start year of forcing data
   integer, parameter :: startmo = 1              ! start month of forcing data
   integer, parameter :: startday= 1              ! start day of forcing data
   integer, parameter :: startsec= 1800           ! start seconds of forcing data
   integer, parameter :: endyr   = 2020           ! end year of forcing data
   integer, parameter :: endmo   = 12             ! end month of forcing data
   integer, parameter :: dtime(NVAR)  = 3600      ! temporal resolution
   integer, parameter :: offset(NVAR) = 0         ! time offset (seconds)
   integer, parameter :: nlands  = 1              ! land grid number in 1d

 ! not applied for POINT
   logical, parameter :: leapyear = .true.        ! leapyear calendar
   logical, parameter :: data2d   = .true.        ! data in 2 dimension (lon, lat)
   logical, parameter :: hightdim = .false.       ! have "z" dimension
   logical, parameter :: dim2d    = .false.       ! lat/lon value in 2 dimension (lon, lat)
   logical, parameter :: latrev   = .true.        ! need to reverse latitudes
   logical, parameter :: lonadj   = .true.        ! need to adjust longitude, 0~360 -> -180~180

 ! not applied for POINT
   character(len=256), parameter :: latname = 'NULL' ! dimension name of latitude
   character(len=256), parameter :: lonname = 'NULL' ! dimension name of longitude

 ! not applied for POINT
   character(len=256), parameter :: groupby = 'NULL'

 ! prefix of forcing data file
   character(len=256), parameter :: fprefix = 'NC'


   character(len=256), parameter :: vname(NVAR) = [character(len=256) :: &
      'Tair', 'Qair', 'PSurf', 'Rainf', 'Wind_E', 'Wind_N', 'SWdown', 'LWdown']

 ! not applied for POINT
   character(len=256), parameter :: tintalgo(NVAR) = 'NULL'

   INTERFACE getfilename
      MODULE procedure getfilename
   END INTERFACE

   INTERFACE metpreprocess
      MODULE procedure metpreprocess
   END INTERFACE

   public metpreprocess

CONTAINS

   FUNCTION getfilename(year, month, var_i)

      implicit none
      integer, intent(in) :: year
      integer, intent(in) :: month
      integer, intent(in) :: var_i
      character(len=256)  :: getfilename

      getfilename = '/'//trim(fprefix)
      return
   END FUNCTION getfilename

 ! preprocess for forcing data [not applicable yet for POINT]
 ! ------------------------------------------------------------
   SUBROUTINE metpreprocess(forcn)

      implicit none
      real(r8), intent(inout) :: forcn(:,:,:)

      real(r8) :: es, esdT, qsat_tmp, dqsat_tmpdT

!----------------------------------------------------------------------------
! use polynomials to calculate saturation vapor pressure and derivative with
! respect to temperature: over water when t > 0 c and over ice when t <= 0 c
! required to convert relative humidity to specific humidity
!----------------------------------------------------------------------------

      call qsadv(forcn(1,1,1),forcn(1,1,3),es,esdT,qsat_tmp,dqsat_tmpdT)
      if (qsat_tmp < forcn(1,1,2)) forcn(1,1,2) = qsat_tmp


   END SUBROUTINE metpreprocess

#endif


END MODULE user_specified_forcing
! ----------- EOP ---------------
