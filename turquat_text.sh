#!/bin/bash

# TURQUAT: Turbo QUASAR ASL Bayesian Analysis Tool
#
# Moss Zhao, Michael Chappell, QUBIC Group, IBME, University of Oxford Image
#
# Copyright (c) 2018-2018 University of Oxford
#
# SHCOPYRIGHT

# Make script use local copies of helper scripts/programs in the same
# directory, if present. This allows for multiple versions of the scripts
# to be used, possibly with bundled dependencies
PATH=`dirname $0`:${FSLDEVDIR}/bin:${FSLDIR}/bin:${PATH}

abspath() {                                               
    # Return an absolute path if the input is relative
    cd "$(dirname "$1")"
    printf "%s/%s\n" "$(pwd)" "$(basename "$1")"
}

Usage() {
    # For future development, I have commented some potentially useful options
    echo "Turbo QUASAR ASL Bayesian Analysis Tool"
    echo "Beta version: it only works for AMC's file format:"
    echo "Shift 1 Repeat 1 Tag, Shift 1 Repeat 1 Control, Shift 2 Repeat 1 Tag, Shift 2 Repeat 1 Control."
    echo ""
    echo "Usage (optional parameters in {}):"
    echo "Example (healthy control): turquat -i XXX -o XXX --calib --corrcal"
    echo "Example (SCD patients): turquat -i XXX -o XXX --calib  --corrcal --tau --infertau"
    echo " -i         : specify data file"
    echo " {-o}       : specify output directory"
    echo " {-m}       : specify brain mask file"
    echo ""
    echo " Extended options:"
    echo " --calib    : include a calibration image (this will automatically tigger the --trans option)"
    echo " --transoff : transform the calibration image to the current data resolution"
    echo " --TR_calib : TR of the calibration image. It needs to be corrected if less than 5.0s {default: 5.0s}"
    echo " --struct   : structural image (T1 or T2 weighted)"
    echo " --t1b      : Set the value for T1 of arterial blood {default: 1.6 s}"
    echo " --corrcal  : Correct partial volume effects on the edge of calibration image M0a"
    echo " --infertau : estimate bolus duration from data"
    echo " --taulowest: lowest possible bolus duration {default: 0.2s}"
    echo " --inferart : estimate arterial blood volume (ABV) from the arterial blood component"
    # Future development
    #echo " --disp     : include bolus dispersion in the model; choices: none(default), gamma"
    # Future development
    #echo " --mfree    : Do model-free (SVD deconvolution) analysis"
    # Future development of partial volume correction options
    #echo ""
    #echo " Partial volume effects correction options:"
    #echo " --pvcorr   : Set partial volume effect correction on. You should provide high resolution partial volume estimates and a structural image."
    #echo " --fslanat  : Name of the directory containing the output from fsl_anat"
    #echo " --t1wm     : T1 for WM {default: 1.1 s}"
    #echo ""
    echo " Sequence parameters:"
    echo " --tau      : Set bolus duration {default: 0.6 s}"
    echo " --slicedt  : Set the increase in TI with slice {default: 0.035 s}"
    echo " --alpha    : Inversion efficiency {default: 0.91}"
    echo " --lambda   : Blood-water coefficient factor {default: 0.9}"
    echo " --fa       : Flip angle for LL readout {default: 35 degrees}"
    echo " --lfa      : Lower flip angle for final phase of data {default: 11.7 degrees}"
    echo " --tis      : comma separated list of TI values"
    echo "            {default: 0.04,0.64,1.24,1.84,2.44,3.04,3.64,4.24,4.84,5.44,6.04}"
    echo " --shift    : slice shifting factor {default: 2}"
    echo " --break_1  : slice number of first acquisition point (start from 0) {default: 0}"
    echo " --break_2  : slice number of middle acquisition point (start from 0) {default: 7}"
    echo " --break_3  : slice number of last acquisition point (start from 0) {default: 14}"
    echo " --taupat   : comma separated list of bolus pattern. 1: label, 0: skip"
    echo "            {default: 1, 1, 1, 1, 1, 1, 1}"
    echo ""
}

Version() {
echo "@GIT_SHA1@ @GIT_DATE@"
exit 0
}

# deal with options
if [ -z $1 ]; then
    Usage
    exit 1
fi

until [ -z $1 ]; do

    # look at this option and determine if has an argument specified by an =
    option=`echo $1 | sed s/=.*//`
    arg="" #specifies if an argument is to be read from next item on command line (=1 is is when = is used)

    if [ $option = $1 ]; then
    # no argument to this command has been found with it (i.e. after an =)
    # if there is an argument it will be the next option
        argument=$2
    else
        arg=1
        argument=`echo $1 | sed s/.*=//`
    fi
    takeargs=0;boolarg="";isbool="";

        case $option in
        -o) outflag=1 outdir=$argument
            shift;;
        -i) inflag=1 infile=$argument #input/data file
            shift;;
        -m) mask=$argument
            shift;;
        --calib) calib_data=$argument
                 trans_status=1 # Need to perform transformation of the calibration image
            shift;;
        --transoff) trans_status=0 # No need to perform transformation of the calibration image
            ;;
        --tr) TR_calib=$argument # TR of the calibration image (default is 5)
            shift;;
        --struct) data_struct=$argument
            shift;;
        --t1b) t1b=$argument
            shift;;
        --t1) t1=$argument
            shift;;
        --t1wm) t1wm=$argument
            shift;;
        --slicedt) slicedt=$argument
            shift;;
        --fa) fa=$argument
            shift;;
        --lfa) lfa=$argument
            shift;;
        --shift) shift_factor=$argument
            shift;;
        --break_1) break_1=$argument
            shift;;
        --break_2) break_2=$argument
            shift;;
        --break_3) break_3=$argument
            shift;;
        --disp) disp=$argument
            shift;;
        #--mfree) mfree=1
        #    ;;
        #--edgecorr) isbool=1;
        #	boolarg=edgecorr;
    	#	;;
        --tis) tis=$argument
            shift;;
        #--iform) iform=$argument # to choose the input form of the data
        #    shift;;
        --tau) tau=$argument
            shift;;
        --corrcal) corrcal=1
            ;;
        --alpha) alpha=$argument
            shift;;
        --lambda) lambda=$argument
            shift;;
        --infertau) infertau=1
            ;;
        --taulowest) tau_lowest=$argument
            shift;;
        --inferart) infer_arterial=1
            ;;
        --pvcorr) pvcorr=1
            ;;
        #--pvgm) pvgm_highres=$argument
            #shift;;
        #--pvwm) pvwm_highres=$argument
            #shift;;
        #--s) strim=$argument # structure images for registration and partial volume estimation
            #shift;;
        #--fslanat) fslanat=$argument # Directory containing the output from fsl_anat
        #    shift;;

        --ccmds) calibcmds=$argument
            shift;;
        --debug) debug=1 #debugging option
            ;;
        --version) Version
            ;;
        *)  Usage
            echo "Error! Unrecognised option on command line: $1"
            echo ""
            exit 1;;
        esac

        # sort out a shift required by a command line option that takes arguments
        if [ -z $arg ]; then
        	# an argument has been supplied on the command NOT using an =
        	if [ $takeargs -eq 1 ]; then
        	    shift;
        	fi
        fi
        
        if [ ! -z $isbool ]; then
    	    # this is an (explicit) boolean setting
        	if [ ! -z $arg ]; then
        	    # an argument has been supplied on the command using an =
        	    # set the variable based on the argument
        	    case $argument in
        		on) eval $boolarg=1
        		    ;;
        		off) eval $boolarg=""
        		     ;;
        		1) eval $boolarg=1
        		   ;;
        		0) eval $boolarg=""
        		   ;;
        		*)  Usage
        		    echo "Error! Unrecognised setting for boolean option: $1"
        		    echo ""
        		    exit 1;;
        	    esac
        	else
        	    # no argument has been suppled with this command (NOTE that you cannot supply an arugment to a bool option without an =)
        	    # this sets the variable to true
        	    eval $boolarg=1;
        	fi
        fi

        shift
done

#### --- Procedural ---
asl_file=asl_file
fabber=fabber_asl
asl_mfree=asl_mfree ###~/cproject/asl_mfree/asl_mfree

#### --- Housekeeping ---
# set the output directory here if not specified
if [ -z $outflag ]; then
    echo "Ouput being placed in basil subdirectory of input directory"
    outdir=$indir/quasil;
fi

# Start by looking for the output directory (and create if need be)
count=0
while [ -d $outdir ]; do
    outdir=$outdir"+"
    count=`expr $count + 1`

    if [ $count -gt 20 ]; then
    echo "Error: $outdir too many existing output directories (i.e. shall not add another +)"
    exit
    fi
done
echo "Creating output directory: $outdir"
mkdir $outdir;

# save the starting directory
stdir=`pwd`

# Full path of output directory
outdir=$(abspath $outdir)

# make a temp directory to work in
#tmpbase=`tmpnam`
#tmpbase="haha"
tmpbase="turquat_temp_"
timestamp=$(date +"%H%M%S")
#tempdir=${tmpbase}_turquat
tempdir=$tmpbase$timestamp
mkdir $tempdir

# deal with the TIs
if [ -z $tis ]; then
    # default QUASAR list of TIs
    tis="0.04,0.64,1.24,1.84,2.44,3.04,3.64,4.24,4.84,5.44,6.04"
fi

# deal with bolus patterns
if [ -z $taupat ]; then
    # default QUASAR list of TIs
    taupat="1,1,1,1,1,1,1"
fi

# Create TI list
count=0
tislist=""
tislist_calib="" # only the first four TIs
thetis=`echo $tis | sed 's:,: :g'`
for ti in $thetis; do
    count=`expr ${count} + 1`
    tislist=`echo $tislist --ti${count}=$ti`
    if [ "$count" -le "4" ]; then
        tislist_calib=`echo $tislist_calib --ti${count}=$ti`
    fi
done
# echo "TIs list: $tislist" >> $log
ntis=$count;


# Create bolus pattern list
count=0
taulist=""
thetaus=`echo $taupat | sed 's:,: :g'`
for current_taupat in $thetaus; do
    count=`expr ${count} + 1`
    bolus_pattern_list=`echo $bolus_pattern_list --bolus_${count}=$current_taupat`
done
# echo "bolus pattern list: $bolus_pattern_list" >> $log
ntis=$count;


if [ -z $iform ]; then
    iform="q"
fi

# parameters
#bolus duration - default 0.64 s
if [ -z $tau ]; then
tau=0.6;
fi

#T1b
if [ -z $t1b ]; then
t1b=1.6;
fi

#T1 - this si the prior value, since T1 will be estimated from the data
if [ -z $t1 ]; then
t1=1.3;
fi

#T1WM
if [ -z $t1wm ]; then
    t1wm=1.1;
fi

# calibration parameters
if [ -z $TR_calib ]; then
    TR_calib=5;
fi
# sequence parameters
# slicedt
if [ -z $slicedt ]; then
    slicedt=0.036;
fi
# Flip angles
if [ -z $fa ]; then
    fa=35;
fi
if [ -z $lfa ]; then
    lfa=11.7;
fi
if [ -z $alpha ]; then
    alpha=0.91;
fi
if [ -z $lambda ]; then
    lambda=0.9;
fi

if [ -z $disp ]; then
    disp=none;
fi

# Slice shifting factor
if [ -z $shift_factor ]; then
    shift_factor=1;
fi
if [ -z $break_1 ]; then
    break_1=0;
    break_1_result=$break_1;
fi
if [ -z $break_2 ]; then
    break_2=7;
    break_2_result=`expr $break_2 + 1`;
fi
if [ -z $break_3 ]; then
    break_3=14;
    break_3_result=$break_3;
fi

# Compute segment length
segment_1_length=`expr $break_2 - $break_1`
segment_2_length=`expr $break_3 - $break_2 + 1`
segment_1_length_result=`expr $break_2_result - $break_1_result`
segment_2_length_result=`expr $break_3_result - $break_2_result + 1`


#### --- Pre-processing ---
echo "Pre-processing"
imcp $infile $tempdir/data

#if [ ! -z $fslanat ]; then
#    cp -R $fslanat $tempdir
#fi

cd $tempdir
# Re-arrange the file
# Split the input file into different repeats and shifts
shift_1_repeat_1_tag="shift_1_repeat_1_tag"
shift_1_repeat_1_control="shift_1_repeat_1_control"
shift_1_repeat_1_diff="shift_1_repeat_1_diff"
shift_1_repeat_1_tissue="shift_1_repeat_1_tissue"
shift_1_repeat_1_blood="shift_1_repeat_1_blood"

shift_2_repeat_1_tag="shift_2_repeat_1_tag"
shift_2_repeat_1_control="shift_2_repeat_1_control"
shift_2_repeat_1_diff="shift_2_repeat_1_diff"
shift_2_repeat_1_control_effective="shift_2_repeat_1_control_effective"
shift_2_repeat_1_tag_effective="shift_2_repeat_1_tag_effective"
shift_2_repeat_1_diff_effective="shift_2_repeat_1_diff_effective"
mask_shift_2_effective="mask_shift_2_effective"
shift_2_repeat_1_tissue="shift_2_repeat_1_tissue"
shift_2_repeat_1_blood="shift_2_repeat_1_blood"


fslroi data $shift_1_repeat_1_tag 0 77
fslroi data $shift_1_repeat_1_control 77 77
fslroi data $shift_2_repeat_1_tag 154 77
fslroi data $shift_2_repeat_1_control 231 77

# Create a mask for the whole data. We use shift 1 repeat 1 control data
if [ -z $mask ]; then
# auto generate mask
    fslmaths $shift_1_repeat_1_control -Tmean aslmean
    bet aslmean mask
    fslmaths mask -bin mask
else
    cd $stdir
    imcp $mask $tempdir/mask
    cd $tempdir
fi
mask=mask

# copy mask to output for future reference
cd $stdir
imcp $tempdir/mask $outdir/mask
cd $tempdir

# Rearrange the slices for shift 2
# Do control image first
# Shift 2 We need to split and rearrange the z direction
# Control
fslroi $shift_2_repeat_1_control data_segment_1 0 64 0 64 $break_1 $segment_1_length
fslroi $shift_2_repeat_1_control data_segment_2 0 64 0 64 $break_2 $segment_2_length
fslmerge -z $shift_2_repeat_1_control_effective data_segment_2 data_segment_1 # Segment 2 was scanned first   
# Tag
fslroi $shift_2_repeat_1_tag data_segment_1 0 64 0 64 $break_1 $segment_1_length
fslroi $shift_2_repeat_1_tag data_segment_2 0 64 0 64 $break_2 $segment_2_length
fslmerge -z $shift_2_repeat_1_tag_effective data_segment_2 data_segment_1 # Segment 2 was scanned first 
# Mask
fslroi $mask data_segment_1 0 64 0 64 $break_1 $segment_1_length
fslroi $mask data_segment_2 0 64 0 64 $break_2 $segment_2_length
fslmerge -z $mask_shift_2_effective data_segment_2 data_segment_1 # Segment 2 was scanned first


# Take tag control differences
fslmaths $shift_1_repeat_1_tag -sub $shift_1_repeat_1_control $shift_1_repeat_1_diff
fslmaths $shift_2_repeat_1_tag_effective -sub $shift_2_repeat_1_control_effective $shift_2_repeat_1_diff_effective


# Extract Tissue and Arterial blood components
n_dynamics=7
# There are seven dynamics (last one is low flip angle, discard)
# Shift 1
$asl_file --data=$shift_1_repeat_1_diff --ntis=$n_dynamics --ibf=tis --iaf=diff --split=data_diff_ph_
# Tissue component
fslmaths data_diff_ph_000 -add data_diff_ph_001 -add data_diff_ph_003 -add data_diff_ph_004 -div 4 $shift_1_repeat_1_tissue
# Arterial component
fslmaths data_diff_ph_002 -add data_diff_ph_005 -div 2 -sub $shift_1_repeat_1_tissue $shift_1_repeat_1_blood
# Remove the intermediate images
imrm data_diff_ph_000 data_diff_ph_001 data_diff_ph_002 data_diff_ph_003 data_diff_ph_004 data_diff_ph_005 data_diff_ph_006

# Shift 2
$asl_file --data=$shift_2_repeat_1_diff_effective --ntis=$n_dynamics --ibf=tis --iaf=diff --split=data_diff_ph_
# Tissue component
fslmaths data_diff_ph_000 -add data_diff_ph_001 -add data_diff_ph_003 -add data_diff_ph_004 -div 4 $shift_2_repeat_1_tissue
# Arterial component
fslmaths data_diff_ph_002 -add data_diff_ph_005 -div 2 -sub $shift_2_repeat_1_tissue $shift_2_repeat_1_blood
# Remove the intermediate images
imrm data_diff_ph_000 data_diff_ph_001 data_diff_ph_002 data_diff_ph_003 data_diff_ph_004 data_diff_ph_005 data_diff_ph_006



# Here we need to estimate T1 and flip angle correction (g) values using the control data
# We only need the first four TIs of the control data
# Now estimate T1 and M0 from Shift 1
$asl_file --data=$shift_1_repeat_1_control --ntis=$n_dynamics --ibf=tis --iaf=diff --split=data_control_

# Extract first 4 TI of the first six dynamic
last_TI=0
length=4
fslroi data_control_000 data_control_0_m_0 $last_TI $length
fslroi data_control_001 data_control_1_m_0 $last_TI $length
fslroi data_control_002 data_control_2_m_0 $last_TI $length
fslroi data_control_003 data_control_3_m_0 $last_TI $length
fslroi data_control_004 data_control_4_m_0 $last_TI $length
fslroi data_control_005 data_control_5_m_0 $last_TI $length
fslroi data_control_006 data_control_6_m_0 $last_TI $length

# Merge the first seven TIs
fslmerge -t shift_1_repeat_1_control_TI_4 data_control_0_m_0 data_control_1_m_0 data_control_2_m_0 data_control_3_m_0 data_control_4_m_0 data_control_5_m_0 data_control_6_m_0

# Remove the intermediate files
imrm data_control_000 data_control_001 data_control_002 data_control_003 data_control_004 data_control_005 data_control_006
imrm data_control_0_m_0 data_control_1_m_0 data_control_2_m_0 data_control_3_m_0 data_control_4_m_0 data_control_5_m_0 data_control_6_m_0

# Prepare for a fabber option file
# We estimate these paramters:
# T1, M0t, g(FA correction factor), A(saturation efficiency)
current_options_file="options_calib_shift_1.txt"
echo "Begin T1 and M0 estimation"
echo "# Turbo QUASAR analysis calibration options" >> $current_options_file
echo "--mask=mask" >> $current_options_file
echo "--method=spatialvb" >> $current_options_file
echo "--noise=white" >> $current_options_file
echo "--model=satrecov" >> $current_options_file
echo "--repeats=1" >> $current_options_file
echo "--phases=6" >> $current_options_file
echo $tislist_calib >> $current_options_file
echo "--t1=$t1 --FA=$fa --LFA=$lfa " >> $current_options_file
echo "--slicedt=$slicedt" >> $current_options_file
echo "--print-free-energy" >> $current_options_file
echo "--save-residuals" >> $current_options_file
echo "--save-model-fit" >> $current_options_file
echo "--param-spatial-priors=MN+" >> $current_options_file

# Now perform model fitting to estimate these parameters
$fabber --data=shift_1_repeat_1_control_TI_4 --data-order=singlefile --output=output_calib_shift_1 -@ $current_options_file


# Now estimate T1 and M0 from shift 2
$asl_file --data=$shift_2_repeat_1_control_effective --ntis=$n_dynamics --ibf=tis --iaf=diff --split=data_control_

# Extract first 4 TI of the first six dynamic
last_TI=0
length=4
fslroi data_control_000 data_control_0_m_0 $last_TI $length
fslroi data_control_001 data_control_1_m_0 $last_TI $length
fslroi data_control_002 data_control_2_m_0 $last_TI $length
fslroi data_control_003 data_control_3_m_0 $last_TI $length
fslroi data_control_004 data_control_4_m_0 $last_TI $length
fslroi data_control_005 data_control_5_m_0 $last_TI $length
fslroi data_control_006 data_control_6_m_0 $last_TI $length

# Merge the first seven TIs
fslmerge -t shift_2_repeat_1_control_TI_4_effective data_control_0_m_0 data_control_1_m_0 data_control_2_m_0 data_control_3_m_0 data_control_4_m_0 data_control_5_m_0 data_control_6_m_0

# Remove the intermediate files
imrm data_control_000 data_control_001 data_control_002 data_control_003 data_control_004 data_control_005 data_control_006
imrm data_control_0_m_0 data_control_1_m_0 data_control_2_m_0 data_control_3_m_0 data_control_4_m_0 data_control_5_m_0 data_control_6_m_0

# Prepare for a fabber option file
# We estimate these paramters:
# T1, M0t, g(FA correction factor), A(saturation efficiency)
current_options_file="options_calib_shift_2.txt"
echo "Begin T1 and M0 estimation"
echo "# Turbo QUASAR analysis calibration options" >> $current_options_file
echo "--mask=mask_shift_2_effective" >> $current_options_file
echo "--method=spatialvb" >> $current_options_file
echo "--noise=white" >> $current_options_file
echo "--model=satrecov" >> $current_options_file
echo "--repeats=1" >> $current_options_file
echo "--phases=6" >> $current_options_file
echo $tislist_calib >> $current_options_file
echo "--t1=$t1 --FA=$fa --LFA=$lfa " >> $current_options_file
echo "--slicedt=$slicedt" >> $current_options_file
echo "--print-free-energy" >> $current_options_file
echo "--save-residuals" >> $current_options_file
echo "--save-model-fit" >> $current_options_file
echo "--param-spatial-priors=MN+" >> $current_options_file

# Now perform model fitting to estimate these parameters
$fabber --data=shift_2_repeat_1_control_TI_4_effective --data-order=singlefile --output=output_calib_shift_2 -@ $current_options_file

# Done estimating T1 and M0


# Model based analysis
# Prepare for a fabber option file
echo "Begin model-based analysis"

    # Fixed bolus duration
    # Condition not to infer bolus duration
    # Shift 1
    current_options_file="options_tissue_shift_1.txt"
    echo "# Turbo QUASAR ASL tissue component analysis options" > $current_options_file
    echo "--mask=mask" >> $current_options_file
    echo "--method=spatialvb" >> $current_options_file
    echo "--noise=white" >> $current_options_file
    echo "--model=turboquasar" >> $current_options_file
    echo "--disp=$disp" >> $current_options_file
    #echo "--inferart" >> $current_options_file
    echo "--repeats=1" >> $current_options_file
    echo $tislist >> $current_options_file
    echo "--t1=$t1 --t1b=$t1b --t1wm=$t1wm --tau=$tau --fa=$fa " >> $current_options_file
    echo "--slicedt=$slicedt" >> $current_options_file
    echo $bolus_pattern_list >> $current_options_file
    echo "--slice_shift=$shift_factor" >> $current_options_file
    echo "--onephase" >> $current_options_file
    echo "--usecalib " >> $current_options_file # We incorporate previously estimated T1 and g value as priors
    echo "--infert1" >> $current_options_file # If we infer T1 we must infer T1 of tissue and blood together (must be two of them)
    #echo "--artdir" >> $current_options_file
    # Save model fitting results and residue
    echo "--save-model-fit" >> $current_options_file
    echo "--print-free-energy" >> $current_options_file
    echo "--save-residuals" >> $current_options_file
    # Here we create a shortcut to the latest results directory
    #echo "--link-to-latest" >> $current_options_file

    # Here are the settings
    echo "--PSP_byname1=ftiss" >> $current_options_file # Estimate CBF
    echo "--PSP_byname1_type=M" >> $current_options_file
    echo "--PSP_byname2=delttiss" >> $current_options_file # Estimate ATT
    echo "--PSP_byname2_type=N" >> $current_options_file
    echo "--PSP_byname3=sp_log" >> $current_options_file # Estimate sp log (dispersion parameter, even if dispersion is none)
    echo "--PSP_byname3_type=N" >> $current_options_file
    echo "--PSP_byname4=s_log" >> $current_options_file # Estimate s log (dispersion parameter, even if dispersion is none)
    echo "--PSP_byname4_type=N" >> $current_options_file
    echo "--PSP_byname5=g" >> $current_options_file # Estimate g (FA correction parameter)
    echo "--PSP_byname5_type=I" >> $current_options_file
    echo "--PSP_byname5_image=output_calib_shift_1/mean_g" >> $current_options_file
    echo "--PSP_byname6=T_1" >> $current_options_file # Estimate T1 of tissue
    echo "--PSP_byname6_type=I" >> $current_options_file
    echo "--PSP_byname6_image=output_calib_shift_1/mean_T1t" >> $current_options_file
    echo "--PSP_byname7=T_1b" >> $current_options_file # Estimate T1 of blood
    echo "--PSP_byname7_type=N" >> $current_options_file


    # Now perform model fitting to estimate CBF, ATT, etc
    $fabber --data=$shift_1_repeat_1_tissue --data-order=singlefile --output=output_tissue_shift_1 -@ $current_options_file
    


    # Shift 2
    # Fixed bolus duration
    # Condition not to infer bolus duration
    current_options_file="options_tissue_shift_2.txt"
    echo "# Turbo QUASAR ASL tissue component analysis options" > $current_options_file
    echo "--mask=mask_shift_2_effective" >> $current_options_file
    echo "--method=spatialvb" >> $current_options_file
    echo "--noise=white" >> $current_options_file
    echo "--model=turboquasar" >> $current_options_file
    echo "--disp=$disp" >> $current_options_file
    #echo "--inferart" >> $current_options_file
    echo "--repeats=1" >> $current_options_file
    echo $tislist >> $current_options_file
    echo "--t1=$t1 --t1b=$t1b --t1wm=$t1wm --tau=$tau --fa=$fa " >> $current_options_file
    echo "--slicedt=$slicedt" >> $current_options_file
    echo $bolus_pattern_list >> $current_options_file
    echo "--slice_shift=$shift_factor" >> $current_options_file
    echo "--onephase" >> $current_options_file
    echo "--usecalib " >> $current_options_file # We incorporate previously estimated T1 and g value as priors
    echo "--infert1" >> $current_options_file # If we infer T1 we must infer T1 of tissue and blood together (must be two of them)
    #echo "--artdir" >> $current_options_file
    # Save model fitting results and residue
    echo "--save-model-fit" >> $current_options_file
    echo "--print-free-energy" >> $current_options_file
    echo "--save-residuals" >> $current_options_file
    # Here we create a shortcut to the latest results directory
    #echo "--link-to-latest" >> $current_options_file

    # Here are the settings
    echo "--PSP_byname1=ftiss" >> $current_options_file # Estimate CBF
    echo "--PSP_byname1_type=M" >> $current_options_file
    echo "--PSP_byname2=delttiss" >> $current_options_file # Estimate ATT
    echo "--PSP_byname2_type=N" >> $current_options_file
    echo "--PSP_byname3=sp_log" >> $current_options_file # Estimate sp log (dispersion parameter, even if dispersion is none)
    echo "--PSP_byname3_type=N" >> $current_options_file
    echo "--PSP_byname4=s_log" >> $current_options_file # Estimate s log (dispersion parameter, even if dispersion is none)
    echo "--PSP_byname4_type=N" >> $current_options_file
    echo "--PSP_byname5=g" >> $current_options_file # Estimate g (FA correction parameter)
    echo "--PSP_byname5_type=I" >> $current_options_file
    echo "--PSP_byname5_image=output_calib_shift_2/mean_g" >> $current_options_file
    echo "--PSP_byname6=T_1" >> $current_options_file # Estimate T1 of tissue
    echo "--PSP_byname6_type=I" >> $current_options_file
    echo "--PSP_byname6_image=output_calib_shift_2/mean_T1t" >> $current_options_file
    echo "--PSP_byname7=T_1b" >> $current_options_file # Estimate T1 of blood
    echo "--PSP_byname7_type=N" >> $current_options_file


    # Now perform model fitting to estimate CBF, ATT, etc
    $fabber --data=$shift_2_repeat_1_tissue --data-order=singlefile --output=output_tissue_shift_2 -@ $current_options_file

    # Condition to estimate bolus duration
    if [ ! -z $infertau ]; then

        if [ -z $tau_lowest ]; then
            tau_lowest=0.2;
        fi
        # We need two steps to estimate it
        # Step 1: Estimate CBF and ATT (as the previous step)
        # Step 2: Incorporate results from Step 1 to estimate bolus duration and refine CBF and ATT 
        echo "Inferring bolus duration..."

        # Shift 1
        # Rename the results of the previous step
        mv output_tissue_shift_1 output_tissue_shift_1_step_1
        # Now we need to create a new MVN file to include the new bolus duration parameter
        mvntool --input=output_tissue_shift_1_step_1/finalMVN --output=output_tissue_shift_1_step_1/finalMVN2 --mask=mask --param=3 --new --val=1 --var=1

        # Now create the new option files
        current_options_file="options_tissue_shift_1.txt"
        echo "--infertau" >> $current_options_file # Estimate bolus duration
        echo "--tau_lowest=$tau_lowest" >> $current_options_file # Lowest limit of bolus duration
        echo "--PSP_byname8=tautiss" >> $current_options_file # Estimate bolus duration
        echo "--PSP_byname8_type=N" >> $current_options_file

        $fabber --data=$shift_1_repeat_1_tissue --data-order=singlefile --output=output_tissue_shift_1 -@ $current_options_file --continue-from-mvn=output_tissue_shift_1_step_1/finalMVN2
    

        # Rename the results of the previous step
        mv output_tissue_shift_2 output_tissue_shift_2_step_1
        # Now we need to create a new MVN file to include the new bolus duration parameter
        mvntool --input=output_tissue_shift_2_step_1/finalMVN --output=output_tissue_shift_2_step_1/finalMVN2 --mask=mask_shift_2_effective --param=3 --new --val=1 --var=1

        # Now create the new option files
        current_options_file="options_tissue_shift_2.txt"
        echo "--infertau" >> $current_options_file # Estimate bolus duration
        echo "--tau_lowest=$tau_lowest" >> $current_options_file # Lowest limit of bolus duration
        echo "--PSP_byname8=tautiss" >> $current_options_file # Estimate bolus duration
        echo "--PSP_byname8_type=N" >> $current_options_file

        $fabber --data=$shift_1_repeat_1_tissue --data-order=singlefile --output=output_tissue_shift_2 -@ $current_options_file --continue-from-mvn=output_tissue_shift_2_step_1/finalMVN2


    fi
# Done model based analysis


# Model free analysis (to be implemented)

# Done model free analysis


# Estimate ABV and the arterial blood components
if [ ! -z $infer_arterial ]; then
    echo "Estimateing ABV and arrival time of arterial blood"
    # Prepare a fabber option file
    # Shift 1
    current_options_file="options_blood_shift_1.txt"
    echo "# Turbo QUASAR ASL arterial blood component analysis options" > $current_options_file
    echo "--mask=mask" >> $current_options_file
    echo "--method=spatialvb" >> $current_options_file
    echo "--noise=white" >> $current_options_file
    echo "--model=turboquasar" >> $current_options_file
    echo "--disp=$disp" >> $current_options_file
    echo "--inferart" >> $current_options_file
    echo "--artdir" >> $current_options_file
    echo "--tissoff" >> $current_options_file
    echo "--repeats=1" >> $current_options_file
    echo $tislist >> $current_options_file
    echo "--t1=$t1 --t1b=$t1b --tau=$tau --fa=$fa " >> $current_options_file
    echo "--slicedt=$slicedt" >> $current_options_file
    echo $bolus_pattern_list >> $current_options_file
    echo "--slice_shift=$shift_factor" >> $current_options_file
    echo "--onephase" >> $current_options_file
    echo "--usecalib " >> $current_options_file # We incorporate previously estimated T1 and g value as priors
    #echo "--infert1" >> $current_options_file # If we infer T1 we must infer T1 of tissue and blood together (must be two of them)
    # Save model fitting results and residue
    echo "--save-model-fit" >> $current_options_file
    echo "--print-free-energy" >> $current_options_file
    echo "--save-residuals" >> $current_options_file
    # Here we create a shortcut to the latest results directory
    #echo "--link-to-latest" >> $current_options_file

    # Here are the settings
    echo "--PSP_byname1=fblood" >> $current_options_file # Estimate CBF
    echo "--PSP_byname1_type=M" >> $current_options_file
    echo "--PSP_byname2=deltblood" >> $current_options_file # Estimate ATT
    echo "--PSP_byname2_type=N" >> $current_options_file
    echo "--PSP_byname3=sp_log" >> $current_options_file # Estimate sp log (dispersion parameter, even if dispersion is none)
    echo "--PSP_byname3_type=N" >> $current_options_file
    echo "--PSP_byname4=s_log" >> $current_options_file # Estimate s log (dispersion parameter, even if dispersion is none)
    echo "--PSP_byname4_type=N" >> $current_options_file
    echo "--PSP_byname5=thblood" >> $current_options_file # Estimate angle theta of crushing gradient
    echo "--PSP_byname5_type=N" >> $current_options_file
    echo "--PSP_byname6=phiblood" >> $current_options_file # Estimate angle phi of crushing gradient
    echo "--PSP_byname6_type=N" >> $current_options_file
    echo "--PSP_byname7=bvblood" >> $current_options_file # Estimate volume of blood
    echo "--PSP_byname7_type=N" >> $current_options_file
    echo "--PSP_byname8=g" >> $current_options_file # Incorporate FA correction factor g
    echo "--PSP_byname8_type=I" >> $current_options_file
    echo "--PSP_byname8_image=output_calib_shift_1/mean_g" >> $current_options_file

    # Now perform model fitting to estimate ABV and arrival time to macrovasculature
    $fabber --data=$shift_1_repeat_1_blood --data-order=singlefile --output=output_blood_shift_1 -@ $current_options_file
    
    # Shift 2
    current_options_file="options_blood_shift_2.txt"
    echo "# Turbo QUASAR ASL arterial blood component analysis options" > $current_options_file
    echo "--mask=mask_shift_2_effective" >> $current_options_file
    echo "--method=spatialvb" >> $current_options_file
    echo "--noise=white" >> $current_options_file
    echo "--model=turboquasar" >> $current_options_file
    echo "--disp=$disp" >> $current_options_file
    echo "--inferart" >> $current_options_file
    echo "--artdir" >> $current_options_file
    echo "--tissoff" >> $current_options_file
    echo "--repeats=1" >> $current_options_file
    echo $tislist >> $current_options_file
    echo "--t1=$t1 --t1b=$t1b --tau=$tau --fa=$fa " >> $current_options_file
    echo "--slicedt=$slicedt" >> $current_options_file
    echo $bolus_pattern_list >> $current_options_file
    echo "--slice_shift=$shift_factor" >> $current_options_file
    echo "--onephase" >> $current_options_file
    echo "--usecalib " >> $current_options_file # We incorporate previously estimated T1 and g value as priors
    #echo "--infert1" >> $current_options_file # If we infer T1 we must infer T1 of tissue and blood together (must be two of them)
    #echo "--artdir" >> $current_options_file
    # Save model fitting results and residue
    echo "--save-model-fit" >> $current_options_file
    echo "--print-free-energy" >> $current_options_file
    echo "--save-residuals" >> $current_options_file
    # Here we create a shortcut to the latest results directory
    #echo "--link-to-latest" >> $current_options_file

    # Here are the settings
    echo "--PSP_byname1=fblood" >> $current_options_file # Estimate CBF
    echo "--PSP_byname1_type=M" >> $current_options_file
    echo "--PSP_byname2=deltblood" >> $current_options_file # Estimate ATT
    echo "--PSP_byname2_type=N" >> $current_options_file
    echo "--PSP_byname3=sp_log" >> $current_options_file # Estimate sp log (dispersion parameter, even if dispersion is none)
    echo "--PSP_byname3_type=N" >> $current_options_file
    echo "--PSP_byname4=s_log" >> $current_options_file # Estimate s log (dispersion parameter, even if dispersion is none)
    echo "--PSP_byname4_type=N" >> $current_options_file
    echo "--PSP_byname5=thblood" >> $current_options_file # Estimate angle theta of crushing gradient
    echo "--PSP_byname5_type=N" >> $current_options_file
    echo "--PSP_byname6=phiblood" >> $current_options_file # Estimate angle phi of crushing gradient
    echo "--PSP_byname6_type=N" >> $current_options_file
    echo "--PSP_byname7=bvblood" >> $current_options_file # Estimate volume of blood
    echo "--PSP_byname7_type=N" >> $current_options_file
    echo "--PSP_byname8=g" >> $current_options_file # Incorporate FA correction factor g
    echo "--PSP_byname8_type=I" >> $current_options_file
    echo "--PSP_byname8_image=output_calib_shift_2/mean_g" >> $current_options_file

    # Now perform model fitting to estimate ABV and arrival time to macrovasculature
    $fabber --data=$shift_2_repeat_1_blood --data-order=singlefile --output=output_blood_shift_2 -@ $current_options_file

fi



# Combine the two shifts (take the average)
# Create an output directory
output_dir_temp="output_dir_temp"
mkdir $output_dir_temp

# Rearrage shift 2
# M0t
fslroi output_calib_shift_2/mean_M0t data_segment_1 0 64 0 64 $break_1_result $segment_1_length_result
fslroi output_calib_shift_2/mean_M0t data_segment_2 0 64 0 64 $break_2_result $segment_2_length_result
fslmerge -z output_calib_shift_2/mean_M0t_result data_segment_2 data_segment_1 # Segment 2 was scanned first
# T1t
fslroi output_calib_shift_2/mean_T1t data_segment_1 0 64 0 64 $break_1_result $segment_1_length_result
fslroi output_calib_shift_2/mean_T1t data_segment_2 0 64 0 64 $break_2_result $segment_2_length_result
fslmerge -z output_calib_shift_2/mean_T1t_result data_segment_2 data_segment_1 # Segment 2 was scanned first
# CBF_relative
fslroi output_tissue_shift_2/mean_ftiss data_segment_1 0 64 0 64 $break_1_result $segment_1_length_result
fslroi output_tissue_shift_2/mean_ftiss data_segment_2 0 64 0 64 $break_2_result $segment_2_length_result
fslmerge -z output_tissue_shift_2/mean_ftiss_result data_segment_2 data_segment_1 # Segment 2 was scanned first
# ATT
fslroi output_tissue_shift_2/mean_delttiss data_segment_1 0 64 0 64 $break_1_result $segment_1_length_result
fslroi output_tissue_shift_2/mean_delttiss data_segment_2 0 64 0 64 $break_2_result $segment_2_length_result
fslmerge -z output_tissue_shift_2/mean_delttiss_result data_segment_2 data_segment_1 # Segment 2 was scanned first
# Bolus duration
if [ ! -z $infertau ]; then
    fslroi output_tissue_shift_2/mean_tautiss data_segment_1 0 64 0 64 $break_1_result $segment_1_length_result
    fslroi output_tissue_shift_2/mean_tautiss data_segment_2 0 64 0 64 $break_2_result $segment_2_length_result
    fslmerge -z output_tissue_shift_2/mean_tautiss_result data_segment_2 data_segment_1 # Segment 2 was scanned first
fi
# Arterial blood colume and arrival time to macrovasculature
if [ ! -z $infer_arterial ]; then
    # ABV
    fslroi output_blood_shift_2/mean_fblood data_segment_1 0 64 0 64 $break_1_result $segment_1_length_result
    fslroi output_blood_shift_2/mean_fblood data_segment_2 0 64 0 64 $break_2_result $segment_2_length_result
    fslmerge -z output_blood_shift_2/mean_fblood_result data_segment_2 data_segment_1 # Segment 2 was scanned first
    # Arrival time to macrovasculature
    fslroi output_blood_shift_2/mean_deltblood data_segment_1 0 64 0 64 $break_1_result $segment_1_length_result
    fslroi output_blood_shift_2/mean_deltblood data_segment_2 0 64 0 64 $break_2_result $segment_2_length_result
    fslmerge -z output_blood_shift_2/mean_deltblood_result data_segment_2 data_segment_1 # Segment 2 was scanned first    
fi

# Now compute average CBF, ATT, M0t, T1t, bolus duration
fslmaths output_tissue_shift_1/mean_ftiss -add output_tissue_shift_2/mean_ftiss_result -div 2 -thr 0 $output_dir_temp/CBF_relative
fslmaths output_tissue_shift_1/mean_delttiss -add output_tissue_shift_2/mean_delttiss_result -div 2 -thr 0 $output_dir_temp/ATT
fslmaths output_calib_shift_1/mean_T1t -add output_calib_shift_2/mean_T1t_result -div 2 -thr 0 $output_dir_temp/T1_tissue
fslmaths output_calib_shift_1/mean_M0t -add output_calib_shift_2/mean_M0t_result -div 2 -thr 0 $output_dir_temp/M0t_from_control_data
if [ ! -z $infertau ]; then
    fslmaths output_tissue_shift_1/mean_tautiss -add output_tissue_shift_2/mean_tautiss_result -div 2 -thr 0 $output_dir_temp/Bolus_duration_raw
    # In the analysis the estimated (observed) bolus duration is actually the results of an operation of the actual bolus duration
    # ie. actual_tau_to_be_estimated = (dti - tau_lowest) / 2 * tanh(mean_tautiss) + (dti + tau_lowest) / 2
    # So we need to apply function of tanh to obtain the actual bolus duration to be estimated
    # tanh(x) = (exp(2x)-1)/(exp(2x)+1)
    # Formula: (dti - tau_lowest) / 2 * tanh(x) + (dti + tau_lowest) / 2
    # slope = (dti - tau_lowest) / 2
    # tanh(x) = (exp(2x)-1)/(exp(2x)+1)
    # intercept = (dti + tau_lowest) / 2
    # This needs to be updated
    # dti=0.6 (not always the case)
    dti=0.6
    slope_sub=`echo print $dti-$tau_lowest | perl`
    slope=`echo print $slope_sub/2 | perl`
    intercept_sub=`echo print $dti+$tau_lowest | perl`
    intercept=`echo print $intercept_sub/2 | perl`
    fslmaths output_dir_temp/Bolus_duration_raw -mul 2 -exp -sub 1 output_dir_temp/numerator
    fslmaths output_dir_temp/Bolus_duration_raw -mul 2 -exp -add 1 output_dir_temp/denominator
    fslmaths output_dir_temp/numerator -div output_dir_temp/denominator output_dir_temp/tanh
    fslmaths output_dir_temp/tanh -mul $slope -add $intercept output_dir_temp/Bolus_duration
    #imrm Bolus_duration_raw numerator denominator tanh
fi
# Arterial blood colume and arrival time to macrovasculature
if [ ! -z $infer_arterial ]; then
    # ABV
    fslmaths output_blood_shift_1/mean_fblood -add output_blood_shift_2/mean_fblood_result -div 2 -thr 0 $output_dir_temp/ABV_relative
    # arrival time to macrovasculature
    fslmaths output_blood_shift_1/mean_deltblood -add output_blood_shift_2/mean_deltblood_result -div 2 -thr 0 $output_dir_temp/Arrival_time_blood
fi


# Additional calibration data is provided
if [ ! -z $calib_data ]; then
    echo "Using user provided calibration data..."
    # Move the calib data into the working directory
    imcp $stdir"/"$calib_data ./

    #echo a
    # We need to perform transformation on the calibration data
    if [ ! -z $trans_status ]; then
        echo "Transforming calibration data to Turbo QUASAR ASL resolution..."
        # Move the structural data into the working directory
        imcp $stdir"/"$data_struct ./
        # Extract brain from the structure and calibration data
        struct_brain="struct_brain"
        bet $data_struct $struct_brain
        calib_brain="calib_brain"
        bet $calib_data $calib_brain
        #echo b
        # Register ASL to Structure
        echo "Running Turbo QUASAR ASL to structure registration..."
        flirt -ref $struct_brain -in $output_dir_temp/CBF_relative -out CBF_high -omat turbo_to_struct.mat
        echo "Running calibration image to structure registration..."
        flirt -ref $struct_brain -in $calib_brain -out calib_high -out calib_high -omat calib_to_struct.mat
        echo "Matrix inversion and concatenation..."
        convert_xfm -omat struct_to_turbo.mat -inverse turbo_to_struct.mat
        convert_xfm -omat struct_to_calib.mat -inverse calib_to_struct.mat
        convert_xfm -omat calib_to_turbo.mat -concat struct_to_turbo.mat calib_to_struct.mat
        convert_xfm -omat turbo_to_calib.mat -concat struct_to_calib.mat turbo_to_struct.mat
        echo "Transforming calibration image to Turbo QUASAR ASL resolution..."
        applywarp --ref=$output_dir_temp/CBF_relative --in=$calib_brain --out=$output_dir_temp/calib_M0t --premat=calib_to_turbo.mat --super --interp=spline --superlevel=4

        # Copy the trasnformation matrices to result dirctory
        cp turbo_to_struct.mat calib_to_struct.mat struct_to_turbo.mat struct_to_calib.mat calib_to_turbo.mat turbo_to_calib.mat $output_dir_temp

    # We do not need to perform transformation
    # Copy the calibration image to temp output folder
    else
        imcp $stdir"/"$calib_data $output_dir_temp"/"calib_M0t
    fi

# Use the estimated M0t image from the previous step (saturation recovery model)
else
    echo "Using calibration data estimated from fitting ASL control data to the saturation recovery signal..."
    imcp $output_dir_temp"/"M0t_from_control_data $output_dir_temp/calib_M0t
fi

# Correct the calibration image by median filter, erosion, and extrapolation
# Ref: http://www.sciencedirect.com/science/article/pii/S1053811917307103
fslmaths $output_dir_temp/calib_M0t -mas mask $output_dir_temp/calib_M0t
if [ ! -z $corrcal ]; then
    echo "Correcting partial volume effects on the edge of the calibration data..."
    fslmaths $output_dir_temp/calib_M0t -fmedian M0t_median
    fslmaths M0t_median -ero M0t_ero
    asl_file --data=M0t_ero --ntis=1 --mask=mask --extrapolate --neighbour=5 --out=M0t_extra
    fslmaths M0t_extra -div $lambda $output_dir_temp/M0a_for_absolute_CBF
    #imrm M0t_median M0t_ero M0t_extra

# Otherwise, we dont correct the edge problems
else
    fslmaths $output_dir_temp/calib_M0t -div $lambda $output_dir_temp/M0a_for_absolute_CBF
fi

# Correct TR if the TR of the calibration image is less than 5s
TR_calib_in_ms=`echo print $TR_calib*1000 | perl`
# If else in bash can only handle integer operations
if [ $TR_calib_in_ms -lt 5000 ]; then
    echo "Correcting TR of calibration image..."
    #statements
    # 10.1002/mrm.25197
    # multiple_factor=(1/(1-exp(-TR/T1_of_tissue)))
    correction_factor=`echo "(1/(1-e((-1)*$TR_calib/$t1)))" | bc -l`
    fslmaths $output_dir_temp/calib_M0t -mul $correction_factor $output_dir_temp/calib_M0t
fi

# Now compuate CBF in absolute unit
fslmaths $output_dir_temp/CBF_relative -div $output_dir_temp/M0a_for_absolute_CBF -div $alpha -mul 6000 $output_dir_temp/CBF_absolute
# Arterial blood colume in absolute unit
if [ ! -z $infer_arterial ]; then
    echo "Output ABV is in decimal format"
    fslmaths $output_dir_temp/ABV_relative -div $output_dir_temp/M0a_for_absolute_CBF -div $alpha $output_dir_temp/ABV_absolute
fi

# Copy results to output directory
#cp -R $output_dir_temp $outdir
cp -a $output_dir_temp/. $outdir
#imcp $tempdir/mask $outdir/mask

# clearup
cd "$stdir" # make sure we are back where we started
if [ -z $debug ]; then
    echo "Tidying up..."
    rm -r $tempdir
else
    echo "Intermediate results saved in " $tempdir
    #mv $tempdir .
fi

echo "Turbo QUSAR ASL analysis done!"


# bash turquat_text.sh -i bigdata -o output --calib M0 --tr 4.4 --struct T2_FLAIR_brain --corrcal --infertau --inferart --debug



# bash turquat_text.sh -i bigdata -o output --calib M0 --tr 4.4 --struct T2_FLAIR_brain --corrcal --inferart 


# bash turquat_text.sh -i bigdata -o output --calib M0 --tr 4.4 --struct T2_FLAIR_brain --corrcal --inferart --debug
