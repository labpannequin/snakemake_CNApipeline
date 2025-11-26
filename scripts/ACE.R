library(QDNAseq)
library(QDNAseq.hg38)
library(ACE)

args <- commandArgs(trailingOnly = TRUE)
userpath <- args[1]
outputdir <- args[2]

#userpath <- file.path("/home/hsandakly/work/snakemake_CNApipeline/results/basecalling/sample72")

# if you do not want the output in the same directory, use argument outputdir
runACE(userpath, filetype='bam', binsizes = 1000, ploidies = 2, imagetype='png', outputdir = outputdir)
