# amplicon-processor
##automatically process miseq pair-end fastq amplicon data
##This pipeline is grogramed by using shell by jkyin in 7.2020
usage(){
        echo "Usage:
                -i [abs_input_file_path.txt | required]
                -o [abs_output_dir | required]
                -m [abs_sample_metadata.tsv | required]
                -n [threads | defalut: 4]
                -d [dada2/deblur | chooose one from above, default: dada2]
                -a [silva_fl/silva_v4/gg_fl/gg_v4 | choose one from above, default: gg_v4]
                -h [print this help info]"
        exit -1
}
