![diagram](https://github.com/yjiakang/amplicon/blob/master/picture/Amp.png)
## Prerequisite: QIIME2  
For installation of QIIME2, please refer to https://links.jianshu.com/go?to=https%3A%2F%2Fdocs.qiime2.org%2F2020.6%2Finstall%2F
## mplicon-processor  
Automatically process miseq pair-end fastq amplicon data  This pipeline is grogramed by using shell by jkyin in 7.2020 
```
Usage:
                -i [abs_input_file_path.txt | required]
                -o [abs_output_dir | required]
                -m [abs_sample_metadata.tsv | required]
                -n [threads | defalut: 4]
                -d [dada2/deblur | choose one from above, default: dada2]
                -a [silva_fl/silva_v4/gg_fl/gg_v4 | choose one from above, default: gg_v4]
                -s [sampling depth | default: minimal frequency for using all the samples
                    Can be changed according to table.qzv]
                -p [max depth when performing alpha-rarefication curve| default:5000]
                -h [print this help info]
```
For more detailed help, please refer to https://www.jianshu.com/p/a7680eef6d20
