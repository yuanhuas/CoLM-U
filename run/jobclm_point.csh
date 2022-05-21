#!/bin/csh

#-------------------------------------------------------
# [1] Define the JOB
#-------------------------------------------------------

set RUN_CLM_SRF="YES"     	# "YES" = MAKE CoLM surface characteristic data
                                # "NO"  = NOT make CoLM surface characteristic data

set RUN_CLM_INI="YES"    	# "YES' = MAKE CoLM initial data
                                # "NO"  = Restart run

set RUN_CaMa="NO"       	# "YES" = OPEN CaMa-Flood
                                # "NO"  = CLOSE CaMa-Flood [No river routing]

set RUN_CLM="YES"        	# "YES" = RUN CoLM
                                # "NO'  = NOT RUN CoLM


# case name and simulating time setting
#-------------------------------------------------------
set CASE_NAME   = AU-Cpr           	# case name                                            <MARK #1>
set GREENWICH   = .false.        	# 'true' for greenwich time, 'false' for local time
set LC_YEAR     = 2005          	# which year of land cover data used
set START_YEAR  = 2007          	# model start year                                     <MARK #2>
set START_MONTH = 1             	# model start Month
set START_DAY   = 1             	# model start Julian day
set START_SEC   = 0             	# model start secs of day
set END_YEAR    = 2018          	# model end year
set END_MONTH   = 1             	# model end month, 10
set END_DAY     = 1             	# model end Julian day
set END_SEC     = 0               	# model end secs of day
set SPIN_YEAR   = $START_YEAR     	# spin-up end year, set default to SATRT_YEAR
set SPIN_MONTH  = $START_MONTH    	# spin-up end month, set default to START_DAY
set SPIN_DAY    = $START_DAY      	# spin-up end day, set default to START_DAY
set SPIN_SEC    = $START_SEC      	# spin-up end sec, set default to START_SEC
set TIMESTEP    = 1800.         	# model time step

set WOUT_FREQ   = MONTHLY         	# write output  file frequency: HOURLY/DAILY/MONTHLY/YEARLY
set WRST_FREQ   = MONTHLY     		# write restart file frequency: HOURLY/DAILY/MONTHLY/YEARLY

# model resolution and running scope setting
#-------------------------------------------------------
set LON_POINTS  =  1
set LAT_POINTS  =  1
set EDGE_N      =  -34.00206
set EDGE_E      =  140.58913
set EDGE_S      =  -34.00206
set EDGE_W      =  140.58913

# set forcing observational height (unit: m)
#-------------------------------------------------------
set HEIGHT_V    =  20.0
set HEIGHT_T    =  20.0
set HEIGHT_Q    =  20.0


#-------------------------------------------------------
# [2] Set necessary environment variables
#-------------------------------------------------------

# clm src directory
#-------------------------------------------------------
setenv CLM_ROOT   $HOME/github/CoLM-U                  # <MARK #3>
setenv CLM_INCDIR $CLM_ROOT/include
setenv CLM_SRFDIR $CLM_ROOT/mksrfdata
setenv CLM_INIDIR $CLM_ROOT/mkinidata
setenv CLM_SRCDIR $CLM_ROOT/main
setenv CLM_POSDIR $CLM_ROOT/postprocess

# inputdata directory
setenv DAT_ROOT   $HOME/data/inputdata                 # <MARK #4>
setenv DAT_RAWDIR $HOME/data/CLMrawdata
setenv DAT_ATMDIR $DAT_ROOT/atm/point
setenv DAT_SRFDIR $DAT_ROOT/srf/point/AU-Cpr
setenv DAT_RTMDIR $DAT_ROOT/rtm/global_15min

# file name of forcing and surface data
setenv DAT_SRFNAM AU-Cpr.MOD.nc                        # surface data filename
setenv DAT_URBNAM urban-data-filename                  # only for urban model
setenv DAT_ATMNAM AU-Cpr_2011-2017_OzFlux_Met.INT      # only for point case

# case directory
#-------------------------------------------------------
setenv CAS_ROOT   $HOME/tera02/cases                   # <MARK #5>
setenv CAS_RUNDIR $CAS_ROOT/$CASE_NAME
setenv CAS_OUTDIR $CAS_RUNDIR/output
setenv CAS_RSTDIR $CAS_RUNDIR/restart

mkdir -p $DAT_SRFDIR
mkdir -p $CAS_RUNDIR
mkdir -p $CAS_OUTDIR
mkdir -p $CAS_RSTDIR

set use_mpi    = "NO"
set nproc      = 30
set use_openmp = "YES"
set nthread    = 92


#------------------------------------------------------
# [3] build define.h in ./include directory
#------------------------------------------------------

\cat >! .tmp << EOF
#define	USE_POINT_DATA            ! QIAN/PRINCETON/CRUNCEP/POINT
#define	IGBP_CLASSIFICATION    9  ! USGS/IGBP/PFT/PC
#undef	LAICHANGE                 ! change LAI for each year
#undef	LULCC                     ! Land use and land cover change
#undef	URBAN_MODEL               ! run urban community model
#undef	URBAN_TREE                ! run urban model with trees
#undef	URBAN_WATER               ! run urban model with water
#undef	URBAN_BEM                 ! run urban model with building energy model
#undef	URBAN_ONLY                ! only for urban patch output
#undef	RDGRID                    !
#undef	RAWdata_update            !
#undef	DYN_PHENOLOGY             !
#undef	SOILINI                   !
#define	LANDONLY                  !
#undef	LAND_SEA                  !
#undef	SOIL_REFL_GUESSED         !
#define	SOIL_REFL_READ            !
#define	WO_${WOUT_FREQ}           !
#define	WR_${WRST_FREQ}           !
#undef	CLMDEBUG                  !
#define	HEIGHT_V $HEIGHT_V        !
#define	HEIGHT_T $HEIGHT_T        !
#define	HEIGHT_Q $HEIGHT_Q        !
#define	lon_points $LON_POINTS    !
#define	lat_points $LAT_POINTS    !
EOF

#-------------------------------------------------------#
#              --- USER SETTING END ---                 #
# DO NOT EDIT THE BELOW SCRIPTS UNLESS YOU KNOW EXACTLY #
# WHAT YOU ARE DOING                                    #
#-------------------------------------------------------#

if ( $use_mpi == "YES" ) then
    echo "#define usempi" >> .tmp
endif

if ( $use_openmp == "YES" ) then
    echo "#define OPENMP $nthread" >> .tmp
endif

if ( $RUN_CaMa == "YES" ) then
  echo "#define CaMa_Flood" >> .tmp
else
  echo "#undef  CaMa_Flood" >> .tmp
endif

sed -i 's/\!.*//g' .tmp
sed -i '/^ *$/d' .tmp

cmp --silent .tmp $CLM_INCDIR/define.h || mv -f .tmp $CLM_INCDIR/define.h
cp -f $CLM_INCDIR/define.h $CAS_RUNDIR/define.h

#-------------------------------------------------------
# [4] compling and executing CoLM surface data making
#-------------------------------------------------------
if ( $RUN_CLM_SRF == "YES" ) then

# Compile
echo ''
echo '>>> Start Making the CoLM surface data...'
cd $CLM_SRFDIR
make >& $CAS_RUNDIR/compile.mksrf.log || exit 5

# Create an input parameter namelist file
\cat >! $CAS_RUNDIR/mksrf.stdin << EOF
&mksrfexp
dir_rawdata        = '$DAT_RAWDIR/'
dir_srfdata        = '$DAT_SRFDIR/'
lc_year            = $LC_YEAR
edgen              = $EDGE_N
edgee              = $EDGE_E
edges              = $EDGE_S
edgew              = $EDGE_W
/
EOF

# Executing CoLM initialization'
cp -vf $CLM_SRFDIR/srf.x $CAS_RUNDIR/
#$CLM_SRFDIR/srf.x < $CAS_RUNDIR/mksrf.stdin > $CAS_RUNDIR/exe.mksrf.log || exit 4

echo 'Making the CoLM surface data completed'

endif



#-------------------------------------------------------
# [5] compling and executing CoLM initialization
#-------------------------------------------------------

cd $CLM_INIDIR

# Create an input parameter namelist file
\cat >! $CAS_RUNDIR/mkini.stdin << EOF
&clminiexp
casename = '$CASE_NAME'
dir_srfdata        = '$DAT_SRFDIR/'
dir_restart        = '$CAS_RSTDIR/'
nam_srfdata        = '$DAT_SRFNAM'
nam_urbdata        = '$DAT_URBNAM'
greenwich          = $GREENWICH
lc_year            = $LC_YEAR
s_year             = $START_YEAR
s_month            = $START_MONTH
s_day              = $START_DAY
s_seconds          = $START_SEC
/
EOF

if ( $RUN_CLM_INI == "YES" ) then

# CoLM initialization for startup run
#-------------------------------------------------------
echo ''
echo '>>> Start Making the CoLM initialization...'
make >& $CAS_RUNDIR/compile.mkini.log || exit 5

cp -vf $CLM_INIDIR/initial.x $CAS_RUNDIR/.
#$CLM_INIDIR/initial.x < $CAS_RUNDIR/mkini.stdin > $CAS_RUNDIR/exe.mkini.log || exit 4
echo 'CoLM initialization completed'

else if ( $RUN_CLM == "YES" ) then

# for restart run
#-------------------------------------------------------
echo $CAS_RUNDIR
if (! -e $CAS_RSTDIR/clmini.infolist.lc$LC_YEAR ) then
  echo 'ERROR: no initial run detected, please run clm initialization first!'; exit
endif

sed -e    "s/s_year *=.*/s_year    = ${START_YEAR}/"  \
    -e   "s/s_month *=.*/s_month   = ${START_MONTH}/" \
    -e     "s/s_day *=.*/s_day     = ${START_DAY}/"   \
    -e "s/s_seconds *=.*/s_seconds = ${START_SEC}/"   \
< $CAS_RSTDIR/clmini.infolist.lc$LC_YEAR > .tmp

mv -f .tmp $CAS_RSTDIR/clmini.infolist.lc$LC_YEAR

echo 'CoLM initialization for restart run completed'

endif



#-------------------------------------------------------
# [6] compliling CaMa Flood Model and make namelist file
#-------------------------------------------------------
if ( $RUN_CaMa == "YES" ) then

echo 'Compiling and initilizing CaMa'

setenv CaMa_DIR $CLM_ROOT/CaMa

set RESTART = 1
set SPINUP  = 2

set RESTART_FREQ = 2
if ( $WRST_FREQ == "YEARLY"  ) then
  set RESTART_FREQ = 0
endif
if ( $WRST_FREQ == "DAILY"   ) then
  set RESTART_FREQ = 1
endif
if ( $WRST_FREQ == "MONTHLY" ) then
  set RESTART_FREQ = 2
endif

# compile
cd $CaMa_DIR/gosh
chmod u+x compile.sh
./compile.sh >& $CAS_RUNDIR/compile.CaMa.log || exit 5
echo 'Compiling CaMa Flood Model completed'

# Create an input parameter namelist file for CaMa Flood Model
chmod u+x CaMa_CLM_grid.sh

if ($RUN_CLM_INI == "YES") then
./CaMa_CLM_grid.sh $CAS_RUNDIR $CAS_OUTDIR $CAS_RSTDIR $DAT_RTMDIR $TIMESTEP $SPINUP  $RESTART_FREQ
else
./CaMa_CLM_grid.sh $CAS_RUNDIR $CAS_OUTDIR $CAS_RSTDIR $DAT_RTMDIR $TIMESTEP $RESTART $RESTART_FREQ
endif

echo 'CaMa compiling and initialization completed'

endif



#-------------------------------------------------------
# [7] compiling and executing CoLM model
#-------------------------------------------------------
if ( $RUN_CLM == "YES" ) then

# Compile
cd $CLM_SRCDIR
rm -f $CAS_RUNDIR/compile.main.log

echo ''
echo '>>> Start Making the CoLM...'
make >& $CAS_RUNDIR/compile.main.log || exit 5
cp -vf $CLM_SRCDIR/clmu.x $CAS_RUNDIR/.

cd $CLM_POSDIR
make >& $CAS_RUNDIR/compile.post.log || exit 5
cp -vf $CLM_POSDIR/bin2netcdf $CAS_RUNDIR/output/.

echo 'Compiling CoLM completed'

# Create an input parameter namelist file
\cat >! $CAS_RUNDIR/timeloop.stdin << EOF
&clmexp
casename = '$CASE_NAME'
dir_srfdata        = '$DAT_SRFDIR/'
dir_atmdata        = '$DAT_ATMDIR/'
dir_output         = '$CAS_OUTDIR/'
dir_restart        = '$CAS_RSTDIR/'
nam_atmdata        = '$DAT_ATMNAM'
nam_srfdata        = '$DAT_SRFNAM'
nam_urbdata        = '$DAT_URBNAM'
deltim             = $TIMESTEP
solarin_all_band   = .true.
lc_year            = $LC_YEAR
e_year             = $END_YEAR
e_month            = $END_MONTH
e_day              = $END_DAY
e_seconds          = $END_SEC
p_year             = $SPIN_YEAR
p_month            = $SPIN_MONTH
p_day              = $SPIN_DAY
p_seconds          = $SPIN_SEC
EOF

\cat $CAS_RSTDIR/clmini.infolist.lc$LC_YEAR >> $CAS_RUNDIR/timeloop.stdin

#----------------------------------------------------------------------
# Executing the CoLM

cd $CAS_RUNDIR
rm -f $CAS_RUNDIR/exe.timeloop.log

echo ''
echo 'Executing CoLM...'
#/usr/bin/time ./clm.x < $CAS_RUNDIR/timeloop.stdin > $CAS_RUNDIR/exe.timeloop.log || exit 4

#if ( $use_mpi == "YES" ) then
#    /usr/bin/time -p /usr/bin/mpirun -np $nproc ./clm.x < $CAS_RUNDIR/timeloop.stdin
#else
#    ./clm.x < $CAS_RUNDIR/timeloop.stdin
#endif

echo 'CoLM Execution Completed'

endif

echo ''
echo '-----------------------------------------------------------------'
echo ' End of CoLM job c-shell script                                  '
echo '-----------------------------------------------------------------'
