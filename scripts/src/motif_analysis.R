source_local <- function(fname){
  argv <- commandArgs(trailingOnly = FALSE)
  base_dir <- dirname(substring(argv[grep("--file=", argv)], 8))
  source(paste(base_dir, fname, sep="/"))
}

source_local('dsAnalysis_utilities.R')

library(parallel)


args = commandArgs(T)
mtx_file = args[1]
genome_name = args[2]
output_dir = args[3]
norm_by = args[4]

mtx = read_mtx_scATACpro(mtx_file)
#mtx = filterMat(mtx)
genomeName = 'BSgenome.Hsapiens.UCSC.hg38'
if(grepl(genome_name, pattern = '38'))genomeName = 'BSgenome.Hsapiens.UCSC.hg38'
if(grepl(genome_name, pattern = '19') || grepl(genome_name, pattern = '37'))genomeName = 'BSgenome.Hsapiens.UCSC.hg19'
if(grepl(genome_name, pattern = 'mm9'))genomeName = 'BSgenome.Mmusculus.UCSC.mm9'
if(grepl(genome_name, pattern = 'mm10'))genomeName = 'BSgenome.Mmusculus.UCSC.mm10'

ncore = detectCores()

if(T){
## select variable features first
      seurat.obj = CreateSeuratObject(mtx, project = 'scATAC', assay = 'ATAC',
                                  names.delim = '-')

      if(norm_by == 'log') seurat.obj@assays$ATAC@data = log1p(seurat.obj@assays$ATAC@counts)
      if(norm_by == 'tf-idf') seurat.obj@assays$ATAC@data = TF.IDF(seurat.obj@assays$ATAC@counts)
      
      seurat.obj <- FindVariableFeatures(object = seurat.obj,
                                         selection.method = 'vst',
                                         nfeatures = floor(nrow(mtx) * 0.3))
      vFeatures = VariableFeatures(seurat.obj)
      rm(seurat.obj)
      rnames = rownames(mtx)
      mtx = mtx[rnames %in% vFeatures, ]
}


obj = run_chromVAR(mtx, genomeName, max(1, ncore - 1))
saveRDS(obj, file = paste0(output_dir, '/chromVar_obj.rds'))

