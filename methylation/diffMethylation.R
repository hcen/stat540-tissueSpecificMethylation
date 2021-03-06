#-------------------------------------------------------------------------------
# Differential methylation analysis
# Jessica Lee
# Date created: April 1, 2014
# Last edit: April 3, 2014
#-------------------------------------------------------------------------------
# Set working directories
setwd("~/workspace/stat540.proj/methylation")

# Load libraries
library(wateRmelon)
library(limma)

# Read in data
load("450kMethylationData_probeLevel_norm.RData")
load("450kMethylationData_geneLevelAverage_norm.RData")
load("450kMethylationData_geneLevelPromoterAverage_norm.RData")
load("450kMethylationData_meta_nuke.RData")

# Get me variable names
names <- ls()
datasets <- names[grep("Meta", names, invert = TRUE)] # data only
betasets <- names[grep("Beta", names)]
datasets <- names[grep("Beta", datasets, invert = TRUE)]
meta <- get(names[grep("Meta", names)]) # meta only

# Dataset alias
dataAlias <- c("gene", "promoter", "probe")
names(dataAlias) <- datasets

# Load helper functions
source("helpers.R")

#-------------------------------
# Functions
#-------------------------------
fitAndHit <- function(data, design, coefName, ...) {
	dmFit <- lmFit(data, design)
	dmEbFit <- eBayes(dmFit)
	topTable(dmEbFit, 
	         coef = grep(coefName, colnames(coef(dmEbFit))), 
	         ...)
}

fitAndHitAll <- function(data, formula, meta, coefName, ...) {
	desMat <- model.matrix(formula, meta)	
	lapply(data, fitAndHit, design = desMat, 
	       coefName = coefName, ...)
}

#-------------------------------
# Workspace
#-------------------------------
# Limma throws an error for some probes that have 
# normalized values of -Inf or Inf
# Nuke probes that have -Inf or Inf
nonInfRows <- apply(methylDatNorm, 1, function(row){ 
	all((row != -Inf) & (row != Inf)) 
})
length(which(nonInfRows == FALSE))
methylDatRmInf <- methylDatNorm[nonInfRows, ]
dim(methylDatRmInf)
dim(methylDatNorm)

# Save RmInf as new data so we can lapply in next step
newData <- gsub("methylDatNorm", "methylDatRmInf", datasets)

# Differential methylation analysis with limma
# Get design matrix
desMat <- model.matrix(~ cellTypeSimple, meta)

# Fit linear model, test that cell types doesn't matter
# Get hits
hit <- lapply(getData(newData), fitAndHit, design = desMat, 
             coefName = "cellType", n = Inf)

# One shot method to test various models
hit <- fitAndHitAll(getData(newData), 
                    ~ cellTypeSimple, meta,
                    coefName = "cellType", n = Inf)

# Save top hits
hit <- castGlobal(hit, "Norm|RmInf", "Hit")

# Save data frame
save(methylDatHit,
     file = "450kMethylationData_probeLevel_hit.RData")
save(avgMethylByGeneHit,
     file = "450kMethylationData_geneLevelAverage_hit.RData")
save(avgMethylByGenePromoterHit,
     file = "450kMethylationData_geneLevelPromoterAverage_hit.RData")


#-------------------------------
# Plotting work
#-------------------------------
# Visualize top x hits in heatmap
howMany <- 1000
topForHeat <- lapply(hit, function(x){head(x, n = howMany)})
hitBeta <- Map(function(top, beta){
	subset(beta, rownames(beta) %in% rownames(top))
}, topForHeat, getData(betasets))

getHeatmap <- function(data, meta) {
	col <- c("lightgoldenrod", "lightseagreen")
	heatmap.2(data, col = rdBu, ColSideColors = col[meta$cellTypeSimple], 
	          density.info = "none", trace = "none", 
	          Rowv = TRUE, Colv = TRUE, labCol = FALSE, labRow = FALSE, 
	    			dendrogram = "col", margins = c(1, 15), keysize = 0.7)
	legend("topright", c("stem cell", "somatic cell"), 
	       col = col, pch = 15)	
}
lapply(hitBeta, function(data, meta) {
	dev.new()
	getHeatmap(data, meta)
}, meta)

# Save heatmap
Map(function(beta, name) {
	pdf(paste("top", howMany, name, "heatmap.pdf", sep = "-"),
	    width = 10, height = 10)
	getHeatmap(beta, meta)
	dev.off()
}, hitBeta, dataAlias)


# Visualize as Stripplot
top5 <- lapply(hit, function(x){head(x, n = 5)})
hitBeta <- Map(function(top, beta){
	subset(beta, rownames(beta) %in% rownames(top))
}, top5, getData(betasets))

getStrip <- function(data, meta) {
	tmp <- melt(data)
	colnames(tmp) <- c("gene", "sample", "beta")
	tmp <- cbind(tmp, cellType = meta$cellTypeSimple[tmp$sample])
	
	return (ggplot(tmp, aes(cellType, beta, color = cellType)) +
		geom_point(position = position_jitter(width = 0.05)) +
		stat_summary(fun.y = mean, aes(group = 1), geom = "line", color = "black") + 
		facet_grid(~ gene) + xlab("Cell Type") + ylab("Beta Value") +
		labs(title = "Top 5 DMR") + 
		theme(legend.title=element_blank()))
}
top5Strip <- lapply(hitBeta, getStrip, meta)
top5Strip <- showMultiPlot(top5Strip)

