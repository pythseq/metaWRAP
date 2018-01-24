#!/bin/bash -l

##############################################################################################################################################################
#
# Quick-pass functional annotation of a set of bins by using PROKKA
#
# Author of pipeline: German Uritskiy. I do not clain any authorship of the many programs this pipeline uses.
# For questions, bugs, and suggestions, contact me at guritsk1@jhu.edu.
# 
##############################################################################################################################################################


help_message () {
	echo ""
	echo "Usage: metaWRAP annotate_bins [options] -o output_dir -b bin_folder"
	echo ""
	echo "Options:"
	echo ""
	echo "	-o STR		output directory"
	echo "	-t INT		number of threads (default=1)"
	echo "	-b STR		folder with metagenomic bins in fasta format"
	echo ""
	echo "";}

comm () { ${SOFT}/print_comment.py "$1" "-"; }
error () { ${SOFT}/print_comment.py "$1" "*"; exit 1; }
warning () { ${SOFT}/print_comment.py "$1" "*"; }
announcement () { ${SOFT}/print_comment.py "$1" "#"; }

# these functions are for parallelizing the annotation
open_sem(){
    mkfifo pipe-$$
    exec 3<>pipe-$$
    rm pipe-$$
    local i=$1
    for((;i>0;i--)); do
        printf %s 000 >&3
    done
}
run_with_lock(){
    local x
    read -u 3 -n 3 x && ((0==x)) || exit $x
    (
    "$@" 
    printf '%.3d' $? >&3
    )&
}

########################################################################################################
########################               LOADING IN THE PARAMETERS                ########################
########################################################################################################


# setting scripts and databases from config file (should be in same folder as main script)
source config-metawrap

# default params
threads=1; bins=None; out=None

# load in params
OPTS=`getopt -o ht:o:b: --long help -- "$@"`
# make sure the params are entered correctly
if [ $? -ne 0 ]; then help_message; exit 1; fi

# loop through input params
while true; do
        case "$1" in
                -t) threads=$2; shift 2;;
                -o) out=$2; shift 2;;
		-b) bins=$2; shift 2;;
                -h | --help) help_message; exit 0; shift 1;;
                --) help_message; exit 1; shift; break ;;
                *) break;;
        esac
done


########################################################################################################
########################           MAKING SURE EVERYTHING IS SET UP             ########################
########################################################################################################

# check if all parameters are entered
if [ $out = "None" ] || [ $bins = "None" ]; then 
	comm "Some non-optional parameters were not entered"
	help_message; exit 1
fi

if [ ! -d $bins ]; then error "$bins does not exist! Exiting."; fi

# Checks for correctly configures meta-scripts folder
if [ ! -s $SOFT/sort_contigs.py ]; then
	error "The folder $SOFT doesnt exist. Please make sure config.sh is in the same filder as the mains scripts and all the paths in the config.sh file are correct"
fi

########################################################################################################
########################               BEGIN ANNOTATION PIPELINE!               ########################
########################################################################################################
announcement "BEGIN ANNNOTAION PIPELINE!"
comm "setting up output folder and copything over bins..."
if [ ! -d $out ]; then
        mkdir $out;
else
        echo "Warning: $out already exists."
fi

if [ -d ${out}/prokka_out ]; then rm -r ${out}/prokka_out; fi
mkdir ${out}/prokka_out


annotate () {
	bin_name=${1%.*}
	bin_file=${bins}/$1
	comm "NOW ANNOTATING ${bin_name}"

	prokka --outdir ${out}/prokka_out/$bin_name --prefix $bin_name $bin_file
	
	if [[ ! -s ${out}/prokka_out/${bin_name}/${bin_name}.gff ]]; then
                error "Something went wrong with reassembling ${bin_name}. Exiting..."
	fi
}

open_sem $threads
for i in $(ls ${bins}); do 
	run_with_lock annotate $i
done

wait
sleep 1
comm "PROKKA finished annotating all the bins!"



########################################################################################################
########################                 FORMATTING ANNOTATIONS                 ########################
########################################################################################################
announcement "FORMATTING ANNNOTAIONS..."

mkdir ${out}/bin_funct_annotations
for i in $(ls ${out}/prokka_out/); do
	grep product ${out}/prokka_out/${i}/${i}.gff > ${out}/bin_funct_annotations/${i}.gff
done


mkdir ${out}/bin_translated_genes
for i in $(ls ${out}/prokka_out/); do
        cp ${out}/prokka_out/${i}/${i}.faa ${out}/bin_translated_genes
done


mkdir ${out}/bin_untranslated_genes
for i in $(ls ${out}/prokka_out/); do
        cp ${out}/prokka_out/${i}/${i}.ffn ${out}/bin_untranslated_genes
done

comm "You will find the bin annotation gff files in ${out}/bin_funct_annotations."

########################################################################################################
########################    ANNOTATION PIPELINE SUCCESSFULLY FINISHED!!!        ########################
########################################################################################################
announcement "ANNOTATE BINS PIPELINE SUCCESSFULLY FINISHED!!!"
