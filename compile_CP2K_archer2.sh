# This is contains all the mechanics of the compilation and install process...
#
# We basically just download, extract, configure and make each external dependency 
# and then link them with the archer2.sopt file. Finally we run the CP2K makefile 
# and hope for the best.
#
# If you have questions then email Matt at: 95ellismle@gmail.com (or chat on slack)
#	He will try to help :) 

set -e

# All the required variables
REQ_VAR="BRANCH ARCH_FILE"
REQ_FILES="compile_CP2K_archer2.sh config.sh $ARCH_FILE"

# Save some useful folderpaths
INSTALL_SCRIPTS_DIR=$(pwd)
LOG_FILE_DIR="$INSTALL_SCRIPTS_DIR/Log_files"
LIB_COMPLETED_FILE="$INSTALL_SCRIPTS_DIR/libs_completed.txt"
if ! [ -d "$LOG_FILE_DIR" ]
then
	mkdir $LOG_FILE_DIR
fi
DOWNLOADS_DIR="$INSTALL_SCRIPTS_DIR/Downloads"
if ! [ -d "$DOWNLOADS_DIR" ]
then
	mkdir $DOWNLOADS_DIR
fi
cd ../
ROOT_DIR=$(pwd)
cd $INSTALL_SCRIPTS_DIR


echo "--------------------------------------------------"
echo "| Installing FOB-SH CP2K on Archer2"
echo "|                        "
echo "| If anything goes wrong the log files for each "
echo "| process are stored in the following directory:"
echo "|   $LOG_FILE_DIR"
echo "|"
echo "|_________________________________________________"


# Initialisation -check we have all files and all variables are declared etc...
for f in $REQ_FILES;
do
	if ! [ -f "$f" ]
	then
		echo " "
		echo "The file '$f' is missing!"
		echo " "
		echo "Please re-download this or ask the person you got this script from to give you it."
		echo " "
	  echo "Exitting"
		exit
	fi
done

# Check we have all required variables 
cont=True
if ! [ -f "config.sh" ]
then
	echo "Please create a file named 'config.sh'"
	cont=false
else
	source config.sh
fi

for name in $REQ_VAR;
do
	var=$(eval "echo \$$name")
	if [ "$var" == "" ]
	then
		echo "Please set the variable '$name' in the file called 'config.sh'"
		cont=false
	fi
done

if [ "$cont" == false ]
then
	echo "Exitting"
	exit
fi

# Totally clean after previous install -if requested
if [ "$CLEAN_INSTALL" == "True" ]
then
	echo "I'm going to do a totally clean install. If you don't want this kill this job now."
	echo "I'll wait for 30 seconds and after that the clean install will begin"
	for ((i=30;i>0;i--))
	do
		printf "\rClean Install in $i seconds    \r"
		sleep 1
	done
	printf "\rStarting Clean Install         \nRemoving previous files...      \n\n"
	rm -rf $DOWNLOADS_DIR
	mkdir $DOWNLOADS_DIR
	rm -rf $ROOT_DIR/flavoured-cptk
	rm -rf $LOG_FILE_DIR
	mkdir $LOG_FILE_DIR
	rm -f $LIB_COMPLETED_FILE
fi


# Change the installation status in the settings file
# args: #1 > the library name
#       #2 > the state to save
function change_lib_state() {
	LIB_NAME=$1
	STATE=$2

	if ! [ -f "$LIB_COMPLETED_FILE" ]
	then
		echo "$LIB_NAME:$STATE" > $LIB_COMPLETED_FILE
	else
		if [ "`grep $LIB_NAME -Poh $LIB_COMPLETED_FILE`" != "" ]
		then
			sed s/"$LIB_NAME:.*"/"$LIB_NAME:$STATE"/ $LIB_COMPLETED_FILE -i
		else
			echo "$LIB_NAME:$STATE" >> $LIB_COMPLETED_FILE
		fi
	fi
}

# Get the state of the variable within the lib completed file (default is False)
#			#1 > the library name
function check_lib_state() {
	LIB_NAME=$1
	if ! [ -f "$LIB_COMPLETED_FILE" ]
	then
		echo "False"
	else
		if [ "`grep $LIB_NAME -Poh $LIB_COMPLETED_FILE`" == "" ]
		then
			echo "False"
		else
			str=`grep "$LIB_NAME:" $LIB_COMPLETED_FILE | grep ":.*" -Poh`
			echo ${str:1:10000}
		fi
	fi
}


# Check SSH keys
SSH_FILE="$HOME/.ssh/id_rsa.pub"
if ! [ -f "$SSH_FILE" ]; then 
    echo "Need to create ssh keys!"
    ssh-keygen
    echo " "
    echo " "
    echo "Created ssh keys."
    echo " "
    echo "Now copy the following into the settings page of your github account and re-run this code when you've done it:"
    echo " "
    cat $SSH_FILE
    exit;
fi

# Download our version of CP2K
cd $ROOT_DIR
FLAV_CP2K_DIR="$ROOT_DIR/flavoured-cptk/cp2k"
if ! [ -d "flavoured-cptk" ]
then
    git clone git@github.com:blumberger/flavoured-cptk.git -b $BRANCH
fi


# Download the 7.1 version of CP2K for the data directory
cd $DOWNLOADS_DIR
CP2K_7_STATE=`check_lib_state "CP2K_7"`
if [ "$CP2K_7_STATE" == "False" ]
then
	change_lib_state "CP2K_7" "False"
	wget https://github.com/cp2k/cp2k/releases/download/v7.1.0/cp2k-7.1.tar.bz2
	echo "Extracting CP2K 7.1 into '$DOWNLOADS_DIR/cp2k-7.1'."
	tar xvf cp2k-7.1.tar.bz2 &> $LOG_FILE_DIR/extract_cp2k_7_1.log \
												 2> $LOG_FILE_DIR/extract_cp2k_7_1.err
	change_lib_state "CP2K_7" "True"
else
	echo " "
	echo "CP2K 7.1 already downloaded."
fi
CP2K7_DIR="$DOWNLOADS_DIR/cp2k-7.1"


# Set CP2K Root
cd $FLAV_CP2K_DIR
export CP2K_ROOT=`pwd`


# Set compilers to GNU compilers with correct version (and get python)
module restore PrgEnv-gnu &> /dev/null 2> /dev/null
module swap gcc/10.1.0 gcc/9.3.0
module load cray-python


#***********************
# Install Libraries
#***********************
# LIBINT
LIBINT_STATE=`check_lib_state "LIBINT"`
if [[ "$DO_LIBINT" == True  || "$LIBINT_STATE" == "False"  && "$DO_LIBINT" != "False" ]]
then
	echo " "
	echo "--------------- LIBINT ---------------------"
	change_lib_state "LIBINT" "False"

	cd $DOWNLOADS_DIR
	LIBINT_LOG="$LOG_FILE_DIR/libint"
	wget https://github.com/cp2k/libint-cp2k/releases/download/v2.6.0/libint-v2.6.0-cp2k-lmax-4.tgz
	tar zxvf libint-v2.6.0-cp2k-lmax-4.tgz
	cd libint-v2.6.0-cp2k-lmax-4

	echo "Configuring Libint"
	CC=cc CXX=CC FC=ftn LDFLAGS=-dynamic ./configure \
           --enable-fortran --with-cxx-optflags=-O \
                 --prefix=${CP2K_ROOT}/libs/libint \
										    &> $LIBINT_LOG\_config.log \
	   										2> $LIBINT_LOG\_config.err
	echo "Making Libint -this will take quite a while!"
	make &> $LIBINT_LOG\_make.log 2> $LIBINT_LOG\_make.err
	echo "Installing Libint"
	make install &> $LIBINT_LOG\_make_inst.log 2> $LIBINT_LOG\_make_inst.err

	change_lib_state "LIBINT" "True"
	echo " "
	echo "LIBINT Installed"
	echo " "
fi


# LIBXSMM
LIBXSMM_STATE=`check_lib_state "LIBXSMM"`
if [[ "$DO_LIBXSMM" == True || "$LIBXSMM_STATE" == "False" && "$DO_LIBXSMM" != "False" ]]
then
	echo " "
	echo "-------------- LIBXSMM --------------------"
	change_lib_state "LIBXSMM" "False"
	cd $DOWNLOADS_DIR
	LIBXSMM_LOG="$LOG_FILE_DIR/libxsmm"

	wget https://github.com/hfp/libxsmm/archive/1.16.1.tar.gz
	echo "Extracting LibXSMM into '$DOWNLOADS_DIR/libxsmm-1.16.1'"
	tar zxvf 1.16.1.tar.gz &> "$LIBXSMM_LOG\extract.log" 2> "$LIBXSMM_LOG\extract.err"
	cd libxsmm-1.16.1

	echo "Making LibXSMM"
	make CC=cc CXX=CC FC=ftn INTRINSICS=1      \
		PREFIX=${CP2K_ROOT}/libs/libxsmm install \
		&> $LIBXSMM_LOG\_make.log 2> $LIBXSMM_LOG\_make.err

	change_lib_state "LIBXSMM" "True"
	echo " "
	echo "LIBXSM Installed"
	echo " "
fi


# LIBXC
LIBXC_STATE=`check_lib_state "LIBXC"`
if [[ "$DO_LIBXC" == True || "$LIBXC_STATE" == "False" && "$DO_LIBXC" != "False" ]]
then
	echo " "
	echo "--------------- LIBXC ----------------------"
	change_lib_state "LIBXC" "False"
	cd $DOWNLOADS_DIR
	LIBXC_LOG="$LOG_FILE_DIR/libxc"

	wget -O libxc-4.3.4.tar.gz https://www.tddft.org/programs/libxc/down.php?file=4.3.4/libxc-4.3.4.tar.gz
	echo "Extracting LIBXC into '$DOWNLOADS_DIR/libxc-4.3.4'"
	tar zxvf libxc-4.3.4.tar.gz &> $LIBXC_LOG\_extract.log \
															2> $LIBXC_LOG\_extract.err
	cd libxc-4.3.4
	
	echo "Configuring LIBXC"
	CC=cc CXX=CC FC=ftn ./configure --prefix=${CP2K_ROOT}/libs/libxc \
		&> $LIBXC_LOG\_conf.log 2> $LIBXC_LOG\_conf.err

	echo "Making LIBXC"
	make &> $LIBXC_LOG\_make.log 2> $LIBXC_LOG\_make.err
	echo "Checking LIBXC"
	make check &> $LIBXC_LOG\_make_check.log 2> $LIBXC_LOG\_make_check.err
	echo "Installing LIBXC"
	make install &> $LIBXC_LOG\_make_inst.log 2> $LIBXC_LOG\_make_inst.err

	change_lib_state "LIBXC" "True"
	echo " "
	echo "LIBXC Installed"
	echo " "
fi



# ELPA
ELPA_STATE=`check_lib_state "ELPA"`
if [[ "$DO_ELPA" == True || "$ELPA_STATE" == "False" && "$DO_ELPA" != "False" ]]
then
	echo " "
	echo "----------------- ELPA ----------------------"
	change_lib_state "ELPA" "False"
	cd $DOWNLOADS_DIR
	ELPA_LOG="$LOG_FILE_DIR/ELPA"

	wget https://elpa.mpcdf.mpg.de/html/Releases/2020.05.001/elpa-2020.05.001.tar.gz
	echo "Extracting ELPA into '$DOWNLOADS_DIR/elpa-2020.05.001'"
	tar xvf elpa-2020.05.001.tar.gz &> $ELPA_LOG\_extract.log \
																	2> $ELPA_LOG\_extract.err
	cd elpa-2020.05.001

	if [ -d "build-serial" ]
	then
		rm -rf build-serial
	fi
	mkdir build-serial
	cd build-serial
	echo "Configuring ELPA"
	CC=cc CXX=CC FC=ftn LDFLAGS=-dynamic ../configure       \
						  --enable-openmp=no --enable-shared=no     \
  --disable-avx512 --prefix=${CP2K_ROOT}/libs/elpa-serial \
			&> $ELPA_LOG\_conf.log 2> $ELPA_LOG\_conf.err

	echo "Making ELPA"
	make &> $ELPA_LOG\_make.log 2> $ELPA_LOG\_make.err
	echo "Installing ELPA"
	make install &> $ELPA_LOG\_make_inst.log 2> $ELPA_LOG\_make_inst.err

	change_lib_state "ELPA" "True"
	echo " "
	echo "ELPA Installed"
	echo " "
fi




#-------------------------------------------
# Now compile CP2K and hope everything works
#____________________________________________

cd $FLAV_CP2K_DIR/arch
ARCH="archer2"
VERSION="sopt"
NEW_ARCH_FILE="$ARCH.$VERSION"
cp $INSTALL_SCRIPTS_DIR/$ARCH_FILE "$NEW_ARCH_FILE"

DATA_DIR="$FLAV_CP2K_DIR/data"
ESCAPED_DATA_DIR=$(printf '%s\n' "$DATA_DIR" | sed -e 's/[]\/$*.^[]/\\&/g')
ESCAPED_CP2K_ROOT=$(printf '%s\n' "$FLAV_CP2K_DIR" | sed -e 's/[]\/$*.^[]/\\&/g')
sed s/"DATA_DIR *=.*"/"DATA_DIR    = $ESCAPED_DATA_DIR"/ $NEW_ARCH_FILE -i
sed s/"CP2K_ROOT *=.*"/"CP2K_ROOT   = $ESCAPED_CP2K_ROOT"/ $NEW_ARCH_FILE -i
#cat $NEW_ARCH_FILE

# We need python2 to compile CP2K 4.1 
#module swap gcc/9.3.0 gcc/10.1.0
module unload cray-python
module load cray-fftw

cd ../makefiles
make clean realclean distclean
make -j 4 ARCH=$ARCH VERSION=$VERSION


echo " "
echo " "
echo "All done! Check the executables folder for the CP2K binary."

