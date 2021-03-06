#!/bin/bash
#title           :simulation.sh
#description     :this script executes fcalor for different configurations and calculates various parameters
#author		 :jking
#date            :20130616
#version         :0.1    
#usage		 :bash simulation.sh
#notes           :requires samplingfractionECal.cc and samplingresolution.cc

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Set work directory
workdir=/afs/cern.ch/work/p/pandolf/geant4/ForwardCaloUpgrade/GEANT

if [ "`pwd`" != "$workdir" ] ; then
    echo -e "You should run this script from your work directory as some links might not yet be set absolute"
    exit
fi




if [ $# -ne 5 ] && [ $# -ne 6 ] ; then
    echo "USAGE: ./simulation_750MeV_batch.sh [full/clean/root] nLayers activeLayerThickness absorberLayerThickness transverseCellSize particleImpactPosition[=0mm]"
    exit
fi



# Usage

if [ "$1" != "clean" ]  && [ "$1" != "root" ] && [ "$1" != "full" ] ; then

    echo -e "Error: missing or invalid argument. Please give one of the following options.\n\nfull: Run GEANT Standalone and root analysis macro\nroot: Run only root analysis macro (requires use of 'full' option before).\nclean: Erase all rootfiles, tables, and inputfiles created by 'root' option.\n"
    exit
fi

# Clean up mode (needs to be adjusted to $storename, $outfilename etc.)

if [ "$1" == "clean" ] ; then

    rm -v $workdir/rootfiles/*
    rm -v $workdir/tables/*
    rm -v -r $workdir/inputfiles/*
    exit
fi

mkdir -p $workdir/rootfiles/temp
mkdir -p $workdir/table
mkdir -p $workdir/inputfiles

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#SETUP SIMULATION
#----------------------------
# To be set in $inputfile:
# default
# /gun/setVxPosition  0.0 0.0 315.0 cm

MyGeant=/afs/cern.ch/user/p/pandolf/geant4/9.4.p02/x86_64-slc6-gcc46-opt/bin/Linux-g++
runnumber=`date +"%d%H%M"`


#Set number of different configurations to simulate (The following arrays must have size #configs)
configs=1

# Set absorber and scintillator material
absorber=(Lead)
sensitiv=(CeF3)
# Choose thickness of abs/scint
absthick=($4)
sensthick=($3)
# Choose particle (mu-,e-)
particle=(e-)
# Choose number of layers
nlayers=($2)
transverseCellSize=($5)
impactPosition=0
if [ $# -eq 6 ]; then
    impactPosition=($6)  
fi
impactPosition_cm=$(echo "${impactPosition}/10" |bc -l)


suffix=n${nlayers}_act${sensthick}_abs${absthick}_trasv${transverseCellSize}
if [ ${impactPosition} -ne 0 ]; then
    suffix=${suffix}_impact${impactPosition}  
fi

#Generic inputfile that is used to create actual inputfiles
inputfile=$workdir/generic_input.in
#Actual inputfiles
#tempfile=$workdir/tempinput.in
tempfile=$workdir/inputfiles/tempinput_${suffix}.in


# Chose file in which Histograms will be stored
storename=${workdir}/rootfiles/samplinghistos_${suffix}.root
# Chose file in which parameter table will be stored
outfilename=${workdir}/tables/parameters_${suffix}.dat


# Choose energies for e- (used to calculate samp_resolution)
energ=(0.75)
# Choose MIP energy (MUST also be contained in e- array)
energ_mip=0

# Choose #events to simulate
events=2500

# Check Arrays sizes
if [ ${#absorber[@]} -ne $configs ] || [ ${#sensitiv[@]} -ne $configs ] || [ ${#absthick[@]} -ne $configs ] || [ ${#sensthick[@]} -ne $configs ] || [ ${#particle[@]} -ne $configs ] || [ ${#nlayers[@]} -ne $configs ] ; then
    echo -e "Error: At least one of the input arrays has wrong size"
    exit 2
fi


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#SHOW PARAMETERS
#------------------------------------
# Basically echo what you have just given as input

echo -e "\nThe following simulation is about to run\n"
echo "runnumber:  $runnumber"
echo "events/run: $events"

echo -e "\nrun \t particle \t nlayers\t d_sens[mm] \t sens \t d_abs[mm] \t abs \t "

runs=$(($configs-1))

for i in `seq 0 $runs`; do
    echo -e "$i \t ${particle[$i]} \t\t ${nlayers[$i]} \t\t ${sensthick[$i]} \t\t ${sensitiv[$i]} \t ${absthick[$i]} \t\t ${absorber[$i]} "
done

echo -e "\nenergies [GeV] (in case of e-)" 
for i in `seq 0 $((${#energ[@]}-1))` ; do
    echo -e "${energ[$i]}"
done
echo -e "\nenergiy [GeV]  for MIPs" 
echo -e "$energ_mip"

if [ "$1" == "root" ] ; then
    echo -e "\nOnly root analysis macro will be executed"
fi

#echo -e "\nDo you want to run the simulation? (y/n)"
#read answer
#if [ "$answer" != "y" ]; then
#    echo -e "Simulation aborted by user\n"
#    exit 1
#fi


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


#RUN SIMULATION
#----------------------------------

if [ ! -e $outfilename ] ; then
    touch $outfilename
fi

echo "Time Start: `date`"  >> $outfilename    
echo "Runnumber: $runnumber"  >> $outfilename    
echo "Events: $events"  >> $outfilename    

n_energ=$((${#energ[@]}-1))

for i in `seq 0 $runs`; do
   
    echo -e "\n---------------------------------------------------------------------"  >> $outfilename    
    echo -e "Configuration: ${absorber[$i]}-${sensitiv[$i]}\n" >> $outfilename
    echo -e "d_sens[mm]\td_abs[mm]\tnlayers\tL(mm)\tL(X0)\tparticle\tenergy\tsf\tsf_width\tR_M " >> $outfilename    
    tgraphname=${i}_resolution_graph
    
    for j in `seq 0 ${n_energ}` ; do
	
#For MIPS use only one energy
	if [ "${particle[$i]}" == "mu-" ] && [ "${energ[$j]}" != "$energ_mip" ] ; then 
	    continue
	fi

#Choose rootfile to save info about single run
	rootfile=rootfiles/temp/temp_${suffix}.root
	#rootfile=rootfiles/temp/${i}_${energ[$j]}.root
	touch $rootfile
	#rootfile_sed="rootfiles\/temp\/${i}_${energ[$j]}.root"  #sed doesn't like /
	rootfile_sed="rootfiles\/temp\/temp_${suffix}.root"  #sed doesn't like /
	
#Modify generic_input.in

	cp $inputfile $tempfile
	sed -i'' "/\/det\/setEcalAbsMat/s/myabs/${absorber[$i]}/g" $tempfile 
	sed -i'' "/\/det\/setEcalSensMat/s/mysens/${sensitiv[$i]}/g" $tempfile 
	sed -i'' "/\/run\/beamOn/s/myevents/$events/g" $tempfile 
	sed -i'' "/\/gun\/particle/s/myparticle/${particle[$i]}/g" $tempfile 
	sed -i'' "/\/setNbOfLayers/s/mylayers/${nlayers[$i]}/g" $tempfile
	sed -i'' "/\/setEcalAbsThick/s/myabsthick/${absthick[$i]} mm/g" $tempfile
	sed -i'' "/\/setEcalSensThick/s/mysensthick/${sensthick[$i]} mm/g" $tempfile
	sed -i'' "/setRootName/s/myrootfile/${rootfile_sed}/g" $tempfile 
	sed -i'' "/\/gun\/energy/s/myenergy/${energ[$j]}. GeV/g" $tempfile
	sed -i'' "/\/setEcalCells/s/mytransversesize/${transverseCellSize[$i]}/g" $tempfile
	sed -i'' "/\/gun\/setVxPosition/s/0.0 0.0 315.0 cm/${impactPosition_cm[$i]} 0.0 315.0 cm/g" $tempfile

	#if [ ! -d $workdir/inputfiles/${runnumber} ] ; then
	#    mkdir $workdir/inputfiles/${runnumber}
	#fi
	#cp $tempfile $workdir/inputfiles/${runnumber}/$tempfile_${i}_${energ[$j]}

#Execute fcalor

	echo -e "\nRunning fcalor with parameters"
	echo -e "#Layers: ${nlayers[$i]}"
	echo -e "Abs :    ${absthick[$i]}"
	echo -e "Sens:    ${sensthick[$i]}"
	echo -e "Transv cell size:  ${transverseCellSize[$i]}\n"
	echo -e "Particle ${particle[$i]}"
	echo -e "Energy:  ${energ[$j]}"

	sleep 2
	
	if [ "$1" == "full" ] ; then
	    
	    $workdir/fcalor $tempfile # > /dev/null
#	    $MyGeant/fcalor $tempfile # > /dev/null
	    
	fi
	
	if [ $? != 0 ]; then
	    echo -e "ERROR"
	    exit 1
	fi
	
#Calculate sampling fraction
	
	root -l -b -q "$workdir/scripts/samplingfractionECal.cc(\"$workdir\",\"$rootfile\",\"${particle[$i]}\",\"${absthick[$i]}\",\"${sensthick[$i]}\",\"${nlayers[$i]}\",\"${energ[$j]}\" ,\"$outfilename\",\"$runnumber\",\"$i\",\"$storename\",\"$tgraphname\",\"${absorber[$i]}\",\"${sensitiv[$i]}\")"
	
	if [ $? != 0 ]; then
	    echo -e "ERROR"
	    exit 1
	fi
   
    done

#Calculate sampling resolution

    if [ "${particle[i]}" == "e-" ] ; then
	
	echo -e "\nCalculate Sampling resolution\n"
	root -l -b -q  "$workdir/scripts/samplingresolution.cc(\"$storename\",\"$tgraphname\",\"$outfilename\",\"$workdir\",\"$i\")"
	
    fi

done

echo -e "\nTime End: `date`"  >> $outfilename    
echo -e "\n\n"  >> $outfilename


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%











