#!/bin/bash

## integrate from feature/peak files
set -e

input_peaks=$1  ## two or more input features files for two or more samples, seperated by ,

# reading configure file
curr_dir=`dirname $0`
source ${curr_dir}/read_conf.sh
read_conf "$2"
read_conf "$3"

peaks=(${input_peaks//,/ })
peakLength=${#peaks[@]}
peak0=${peaks[0]}
for (( i=1; i<${peakLength}; i++ ));
do
    peak0=${peak0},${peaks[$i]}
done

peak_dir=${OUTPUT_DIR}/peaks
mkdir -p $peak_dir

echo "merge peaks ..."
${R_PATH}/R --vanilla --args ${peak0},200 $peak_dir < ${curr_dir}/src/mergePeaks.R

## remove peaks overlapped with blacklist
feature_file=${peak_dir}/merged_peaks.bed

#${BEDTOOLS_PATH}/bedtools intersect -a ${peak_dir}/merged_peaks.bed -b $BLACKLIST -v \
#    > ${feature_file}

echo "Constructing raw peak-by-cell matrix for each sample ..."
## supporse each sample was constructed by scATAC-pre
## so the fragment files are saved correspondly

ABS_PATH=`cd "$OUTPUT_DIR"; pwd`

## reconstruct the peak-cell matrix
## not re-call cells
mtx_files='TMP' 
for pk0 in "${peaks[@]}"
do 
    sample0=$(basename $pk0)
    sample0=`echo $sample0 | awk -F. '{print $1}'`
    sample0=${sample0/_features_BlacklistRemoved/}
    mkdir -p $raw_mtx_dir
    pk0_dir=$(dirname $pk0)
    frag0_dir=`cd "$pk0_dir"; cd "../../summary"; pwd`       
    mat0_dir=`cd "$pk0_dir"; cd "../../filtered_matrix"; pwd`       
    frag0_file=$(find $frag0_dir -name "*fragments.txt")
    mat0_dir=${mat0_dir}/${PEAK_CALLER}/${CELL_CALLER}
    bc0_file=$(find ${mat0_dir} -name "*barcodes.txt")
    bash ${curr_dir}/reConstMtx.sh ${feature_file},${frag0_file},${bc0_file} $2 $3
    mtx_files=${mtx_files},${mat0_dir}/reConstruct_matrix/matrix.mtx
done

echo "Integrate by Seurat v3 ..."
mtx_files=${mtx_files/TMP,/}

${R_PATH}/Rscript --vanilla ${curr_dir}/src/integrate_seu.R $mtx_files $CLUSTERING_METHOD $K_CLUSTERS $OUTPUT_DIR $GENOME_NAME $TSS $norm_by $REDUCTION $nREDUCTION $Top_Variable_Features

