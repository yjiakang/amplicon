#!/bin/bash
usage(){
	echo "Usage:
       		-i [abs_input_file_path.txt | required]
		-o [abs_output_dir | required]
		-m [abs_sample_metadata.tsv | required]
		-n [threads | defalut: 4]
		-d [dada2/deblur | choose one from above, default: dada2]
		-a [silva_fl/silva_v4/gg_fl/gg_v4 | choose one from above, default: gg_v4]
		-s [sampling depth | default: minimal frequency for using all the samples
		    Can be changed according to table.qzv]
		-p [max depth when performing alpha-rarefication curve| default:5000]
		-h [print this help info]"
	exit -1
}


#default parameters
threads=4 #default threads for processing
denoise_algo="dada2" #default algorithm for denoising data
dataname="gg_v4" #default database
p_max_depth=5000


#function for denoise data using dada2 algorithm
dada2(){
qiime dada2 denoise-paired \
	--i-demultiplexed-seqs ${output_dir}/paired-end-demux.qza \
	--p-trunc-len-f 0 \
	--p-trunc-len-r 0 \
	--p-n-threads $threads \
	--o-table ${denoise_dir}/table.qza \
       	--o-representative-sequences ${denoise_dir}/rep-seqs.qza \
	--o-denoising-stats ${denoise_dir}/stats.qza 
}


#function for denoise data using deblur algorithm
deblur(){
#merge first
qiime vsearch join-pairs \
	--i-demultiplexed-seqs ${output_dir}/paired-end-demux.qza \
	--o-joined-sequences ${denoise_dir}/demux-joined.qza
#summarize
qiime demux summarize \
	--i-data ${denoise_dir}/demux-joined.qza \
	--o-visualization ${denoise_dir}/demux-joined.qzv
#quality 
qiime quality-filter q-score \
	--i-demux ${denoise_dir}/demux-joined.qza \
	--o-filtered-sequences ${denoise_dir}/demux-joined-filtered.qza \
	--o-filter-stats ${denoise_dir}/demux-joined-filter-stats.qza
#denoise
qiime deblur denoise-16S \
	--i-demultiplexed-seqs ${denoise_dir}/demux-joined-filtered.qza \
	--p-trim-length 460 \
	--o-representative-sequences ${denoise_dir}/rep-seqs.qza \
	--o-table ${denoise_dir}/table.qza \
	--p-sample-stats \
	--o-stats ${denoise_dir}/stats.qza
}

#get parameters
while getopts 'i:o:m:n:d:a:s:p:h' opt; do
	case $opt in
		i) input_file="$OPTARG";;
		o) output_dir="$OPTARG";;
		m) metadata_file="$OPTARG";;
		n) threads="$OPTARG";;
		d) denoise_algo="$OPTARG";;
		a) dataname="$OPTARG";;
		s) sample_depth="$OPTARG";;
		p) p_max_depth="$OPTARG";;
		h) usage;;
		?) usage;;
	esac
done
#denoise directory
denoise_dir=${output_dir}/${denoise_algo}


#get qiime env name
qiime=`conda env list | grep "qiime.*" | awk '{print $1}'`
echo "qiime version: "$qiime


#print info to stdout
echo "input file path: "${input_file}
echo "output directory: "${output_dir}
echo "metadata file: "${metadata_file}
echo "threads: "$threads
echo "denoise algothrim: "${denoise_algo}
echo "database: "$dataname
echo "denoise directory: "${denoise_dir}
echo "sampling depth when performing alpha-rarefication curve: "${p_max_depth}


#activate qiime env && make directory for storing output files && preparation of optional parameters
source activate $qiime
if [ ! -d ${output_dir} ];then
	echo "creating output directory: ${output_dir} ..."
	mkdir ${output_dir}
else
	echo "output directory: ${output_dir} has already been created, skipping ..."
fi
if [ ! -d "${output_dir}/database" ];then
	echo "creating database directory: ${output_dir}/database"
	mkdir ${output_dir}/database
else
	echo "database directory has been created: ${output_dir}/database, skipping ..."
fi

#get database url
wget -q -O "${output_dir}/database_url.txt" "https://docs.qiime2.org/${qiime##*-}/data-resources/"
silva_fl_url=`cat ${output_dir}/database_url.txt | grep "nb-classifier" | grep "Silva" | grep "full" | cut -d "\"" -f 4`
silva_v4_url=`cat ${output_dir}/database_url.txt | grep "nb-classifier" | grep "Silva" | grep "515" | cut -d "\"" -f 4`
gg_fl_url=`cat ${output_dir}/database_url.txt | grep "nb-classifier" | grep "Greengenes" | grep "full" | cut -d "\"" -f 4`
gg_v4_url=`cat ${output_dir}/database_url.txt | grep "nb-classifier" | grep "Greengenes" | grep "515" | cut -d "\"" -f 4`


if [ "$dataname" = "gg_v4" ];then
	database="${output_dir}/database/${gg_v4_url##*/}"
	if [ ! -f "${output_dir}/database/${gg_v4_url##*/}" ];then
		echo "downloading gg_v4 database from ${gg_v4_url}"
		wget -q -O "${output_dir}/database/${gg_v4_url##*/}" "${gg_v4_url}"
	fi
elif [ "$dataname" = "gg_fl" ];then
	database="${output_dir}/database/${gg_fl_url##*/}"
	if [ ! -f "${output_dir}/${gg_fl_url##*/}" ];then
		echo "downloading gg_fl database from ${gg_fl_url}"
		wget -q -O "${output_dir}/database/${gg_fl_url##*/}" "${gg_fl_url}"
	fi
elif [ "$dataname" = "silva_fl" ];then
	database="${output_dir}/database/${silva_fl_url##*/}"
	if [ ! -f "${output_dir}/database/${silva_fl_url##*/}" ];then
		echo "downloading silva_fl from ${silva_fl_url}"
		wget -q -O "${output_dir}/database/${silva_fl_url##*/}" "${silva_fl_url}"
	fi
elif [ "$dataname" = "silva_v4" ];then
	database="${output_dir}/database/${silva_v4_url##*/}"
	if [ ! -f "${output_dir}/database/${silva_v4_url##*/}" ];then
		echo "downloading silva_v4 database from ${silva_v4_url}"
		wget -q -O "${output_dir}/database/${silva_v4_url##*/}" "${silva_v4_url}"
	fi
fi

echo "database path: "$database
cd  ${output_dir}

#import data
if [ ! -f ${output_dir}/paired-end-demux.qza ];then
	qiime tools import \
		--type 'SampleData[PairedEndSequencesWithQuality]' \
		--input-path ${input_file} \
		--output-path ${output_dir}/paired-end-demux.qza \
		--input-format PairedEndFastqManifestPhred33V2
else
	echo "data has been imported, skipping ..."
fi
if [ $? -eq 0 ];then
	step1="ok"
else
	echo "error happened when importing data, please check wheather your input file path is ok!"
	exit
fi
#summarize data
if [ ! -f ${output_dir}/paired-end-demux.qzv ];then
	qiime demux summarize \
		--i-data ${output_dir}/paired-end-demux.qza \
		--o-visualization ${output_dir}/paired-end-demux.qzv
else
	echo "imported data has been summarized, skipping ..."
fi
if [ $? -eq 0 ];then
        step2="ok"
else
        echo "error happened when summarizing imported data, please check the former output file used for this step"
	exit
fi


#denoise using dada2 or deblur
echo "running ${denoise_algo} ..."
if [ ! -d ${denoise_dir} ];then
	mkdir ${denoise_dir}
fi


#dada2
if [ "$denoise_algo" = "dada2" ];then
      	if [ ! -f ${denoise_dir}/table.qza ]; then
	        dada2
	else 
		echo "${denoise_algo} has been done, skipping ..."
	fi
fi
if [ "$denoise_algo" = "deblur" ];then
	if [ ! -f ${denoise_dir}/table.qza ];then
		deblur
	else
		echo "${denoise_algo} has been done, skipping ..."
	fi
fi
if [ $? -eq 0 ];then
        step3="ok"
else
        echo "error happened when performing ${denoise_algo} for denoising data, please check!"
	exit
fi

#summarize feature table
echo "summarizing feature table ..."
if [ ! -f ${denoise_dir}/table.qzv ];then
	qiime feature-table summarize \
		--i-table ${denoise_dir}/table.qza \
		--o-visualization ${denoise_dir}/table.qzv \
       		--m-sample-metadata-file ${metadata_file}
else
	echo "feature table has been summarized, skipping ..."
fi
if [ $? -eq 0 ];then
        step4="ok"
else
        echo "error happened when summarizing feature table, please check!"
	exit
fi

#construct the phylogenetic tree for diversity analyses
echo "constructing phylogenetic tree for diversity ananlyses ..."
if [ ! -f ${denoise_dir}/aligned-rep-seqs.qza ];then
	qiime phylogeny align-to-tree-mafft-fasttree \
		--i-sequences ${denoise_dir}/rep-seqs.qza \
		--o-alignment ${denoise_dir}/aligned-rep-seqs.qza \
		--o-masked-alignment ${denoise_dir}/masked-aligned-rep-seqs.qza \
		--p-n-threads $threads \
		--o-tree ${denoise_dir}/unrooted-tree.qza \
		--o-rooted-tree ${denoise_dir}/rooted-tree.qza
else
	echo "phylogenetic tree has been constructed,skipping ..."
fi
if [ $? -eq 0 ];then
        step5="ok"
else
        echo "error happened when constracting the phylogenetic tree, please check!"
	exit
fi


#determine the --p-sampling-depth

determ_samp_dep(){
	cd ${denoise_dir}
	table_dir=`unzip -o ${denoise_dir}/table.qza | awk -F":" 'NR==2{print $2}' | awk -F"/" '{print $1}'`
	cd ${table_dir}/data
	biom convert -i feature-table.biom -o feature-table.txt --to-tsv
	nrow=`awk 'NR==3{print NF}' feature-table.txt`
	for i in `seq 2 $nrow`;do awk -F"\t" -v ncol=$i 'BEGIN{sum=0}{sum+=$ncol}END{print sum}' feature-table.txt >> feature_count.txt;done
	sample_depth=`awk 'NR==1{min=$1;next}{min=min<$1?min:$1}END{print min}' feature_count.txt` #sample the min counts for using all our samples
	cd ../../ && mv -f ${table_dir} table.qza.unzip
	echo "sampling depth: "${sample_depth}
}
if [ ! -n "${sample_depth}" ];then
	echo "determining sampling depth ..."
	determ_samp_dep
	if [ $? -eq 0 ];then
        	step6="ok"
	else
        	echo "error happened when determinging sampling depth, please check!"
		exit
	fi
else
	echo "sampling depth: "${sample_depth}
	step6="ok"
fi

cd ${output_dir}


#Alpha and beta diversity analysis
echo "performing alpha diversity analysis ..."
if [ ! -d "${denoise_dir}/sample-depth-${sample_depth}-core-metrics-results" ];then
	qiime diversity core-metrics-phylogenetic \
		--i-phylogeny ${denoise_dir}/rooted-tree.qza \
		--i-table ${denoise_dir}/table.qza \
		--p-sampling-depth ${sample_depth} \
		--m-metadata-file ${metadata_file} \
		--output-dir ${denoise_dir}/sample-depth-${sample_depth}-core-metrics-results
else
	echo "alpha diversity using sample depth: ${sample_depth} has been done, skipping ..."
fi
if [ $? -eq 0 ];then
        step7="ok"
else
        echo "error happened when performing alpha-diversity analysis, please check if the input file it needs is ok!"
	exit
fi

#Alpha diversity - faith_pd
echo "calculating faith_pd index ..."
if [ ! -f "${denoise_dir}/sample-depth-${sample_depth}-core-metrics-results/faith_pd_vector.qza" ];then
	qiime diversity alpha-group-significance \
		--i-alpha-diversity ${denoise_dir}/sample-depth-${sample_depth}-core-metrics-results/faith_pd_vector.qza \
		--m-metadata-file ${metadata_file} \
		--o-visualization ${denoise_dir}/sample-depth-${sample_depth}-core-metrics-results/faith-pd-group-significance.qzv
else
	echo "faith_pd index using sample depth: ${sample_depth} has been done, skipping ..."
fi
#Rarefication curve
echo "doing rarefication curve ..."
if [ ! -f ${denoise_dir}/p-max-depth-${p_max_depth}-alpha-rarefaction.qzv ];then
	qiime diversity alpha-rarefaction \
		--i-table ${denoise_dir}/table.qza \
		--i-phylogeny ${denoise_dir}/rooted-tree.qza \
		--p-max-depth ${p_max_depth} \
		--m-metadata-file ${metadata_file} \
		--o-visualization ${denoise_dir}/p-max-depth-${p_max_depth}-alpha-rarefaction.qzv
else
	echo "rarefication curve using p-max-depth ${p_max_depth} has been analyzed, skipping ..."
fi

if [ $? -eq 0 ];then
        step8="ok"
else
        echo "error happened when performing rarefication curve analysis, please check!"
	exit
fi


#taxonomic annotation
echo "performing taxonomic annotation using ${dataname}"
if [ ! -f ${denoise_dir}/taxonomy-${denoise_algo}-${dataname}.qza ];then
	qiime feature-classifier classify-sklearn \
		--i-classifier $database \
		--i-reads ${denoise_dir}/rep-seqs.qza \
		--o-classification ${denoise_dir}/taxonomy-${denoise_algo}-${dataname}.qza \
		--p-n-jobs $threads \
		--verbose
else
	echo "taxonomic annotation has been done, skipping ..."
fi

if [ $? -eq 0 ];then
        step9="ok"
else
        echo "error happened when annotating ASV, please check if it was caused by the uncomplete database due to network connection. If yes, just mannually download it."
	exit
fi

#visualization by barplot
echo "visualizing taxonomic composition ..."
if [ ! -f  ${denoise_dir}/taxa-bar-plots-${denoise_algo}-${dataname}.qzv ];then
	qiime taxa barplot \
		--i-table ${denoise_dir}/table.qza \
		--i-taxonomy ${denoise_dir}/taxonomy-${denoise_algo}-${dataname}.qza \
		--m-metadata-file ${metadata_file} \
		--o-visualization ${denoise_dir}/taxa-bar-plots-${denoise_algo}-${dataname}.qzv
else
	echo "visualization of taxonomic composition has been done, skipping ..."
fi

if [ $? -eq 0 ];then
        step10="ok"
else
        echo "error happened when visualizing taxonomic composition, please check the input file this step needs!"
	exit
fi


#final output of processing info - run successfully or not
n=0
for i in `seq 10`;do
	state=`eval echo "$""step"$i`
	if [ $state = "ok" ];then
		((n=n+1))
	fi
done
if [ $n = 10 ];then
	echo "Congratulations! You have successfully finished the amplicon data analyses"
fi
