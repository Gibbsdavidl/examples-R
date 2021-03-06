#' # Expression and Protein Correlation
#' 
#' In this example, we will look at the correlation between mRNAseq-based gene expression data and RPPA-based protein expression data.  We will do this using two molecular data tables from the isb-cgc:tcga_201510_alpha dataset and a cohort table from the isb-cgc:tcga_cohorts dataset.
#' 
## ----message=FALSE-------------------------------------------------------
library(ISBCGCExamples)

# The directory in which the files containing SQL reside.
#sqlDir = file.path("/PATH/TO/GIT/CLONE/OF/examples-R/inst/",
sqlDir = file.path(system.file(package = "ISBCGCExamples"),"sql")

#' 
## ----eval=FALSE----------------------------------------------------------
## ######################[ TIP ]########################################
## ## Set the Google Cloud Platform project id under which these queries will run.
## ##
## ## If you are using the workshop docker image, this is already
## ## set for you in your .Rprofile and you can skip this step.
## 
## # project = "YOUR-PROJECT-ID"
## #####################################################################

#' 
#' ## Spearman Correlation in BigQuery
#' 
#' We will start by performing the correlation directly in BigQuery.  We will use a pre-defined SQL query in which key strings will be replaced according to the values specified in the "replacements" list.
#' 
## ----comment=NA----------------------------------------------------------
# Set the desired tables to query.
expressionTable = "isb-cgc:tcga_201510_alpha.mRNA_UNC_HiSeq_RSEM"
proteinTable = "isb-cgc:tcga_201510_alpha.Protein_RPPA_data"
cohortTable = "isb-cgc:tcga_cohorts.BRCA"

# Do not correlate unless there are at least this many observations available
minimumNumberOfObservations = 30

#' 
#' We'll pause for a moment here and have a look at the size of our cohort table:
#' 
## ----comment=NA----------------------------------------------------------
cohortInfo <- get_table("isb-cgc","tcga_cohorts","BRCA")
cohortInfo$description
cohortInfo$numRows

ptm1 <- proc.time()

# Now we are ready to run the query.
result = DisplayAndDispatchQuery (
             file.path(sqlDir, "protein-mrna-spearman-correlation.sql"),
             project=project,
             replacements=list("_EXPRESSION_TABLE_"=expressionTable,
                               "_PROTEIN_TABLE_"=proteinTable,
                               "_COHORT_TABLE_"=cohortTable,
                               "_MINIMUM_NUMBER_OF_OBSERVATIONS_"=minimumNumberOfObservations) )

ptm2 <- proc.time() - ptm1
cat("Wall-clock time for BigQuery:",ptm2[3])


#' Number of rows returned by this query: `nrow(result)`.
#' 
#' The result is a table with one row for each (gene,protein) pair for which at least 30 data values exist for the specified cohort.  The (gene,protein) pair is defined by a gene symbol and a protein name.  In many cases the gene symbol and the protein name may be identical, but for some genes the RPPA dataset may contain expression values for more than one post-translationally-modified protein product from a particular gene.
#' 
## ------------------------------------------------------------------------
head(result)

#' 
## ----spearman_density, fig.align="center", fig.width=10, message=FALSE, warning=FALSE, comment=NA----
library(ggplot2)

# Use ggplot to create a histogram overlaid with a transparent kernel density curve
ggplot(result, aes(x=spearman_corr)) +
     # use 'density' instead of 'count' for the histogram
     geom_histogram(aes(y=..density..),
                   binwidth=.05,
                   colour="black", fill="white") +
     # and overlay with a transparent density plot
     geom_density(alpha=.2, fill="#FF6666") +
     # and add a vertical line at x=0 to emphasize that most correlations are positive
     geom_vline(xintercept=0)

#' 
#' ## Spearman Correlation in R
#' 
#' Now let's reproduce one of the results directly in R.  The highest correlation value was for the (ESR1,ER-alpha) (gene,protein) pair, so that's the pair that we will use for our validation test.
#' 
#' ### Retrieve Expression Data
#' 
#' First we retrieve the mRNA expression data for a specific gene and only for samples in our cohort.
## ----comment=NA----------------------------------------------------------
# Set the desired gene to query.
gene = "ESR1"

expressionData = DisplayAndDispatchQuery(file.path(sqlDir, "expression-data-by-cohort.sql"),
                                         project=project,
                                         replacements=list("_EXPRESSION_TABLE_"=expressionTable,
                                                           "_COHORT_TABLE_"=cohortTable,
                                                           "_GENE_"=gene))

#' Number of rows returned by this query: `nrow(expressionData)`.
#' 
## ------------------------------------------------------------------------
head(expressionData)

#' 
#' ### Retrieve Protein Data
#' 
#' Next, we retrieve the protein data for a specific (gene,protein) pair, and again only for samples in our cohort.
#' 
## ----comment=NA----------------------------------------------------------
protein = "ER-alpha"

proteinData = DisplayAndDispatchQuery(file.path(sqlDir, "protein-data-by-cohort.sql"),
                                      project=project,
                                      replacements=list("_PROTEIN_TABLE_"=proteinTable,
                                                        "_COHORT_TABLE_"=cohortTable,
                                                        "_GENE_"=gene,
                                                        "_PROTEIN_"=protein))

#' Number of rows returned by this query: `nrow(proteinData)`.
#' 
## ------------------------------------------------------------------------
head(proteinData)

#' 
#' Since protein data is not typically available for as many samples as mRNA expression data, the returned "expressionData" table is likely to be quite a bit bigger than the "proteinData" table.  The next step is an inner join of these two tables:
#' 
## ------------------------------------------------------------------------
library(dplyr)

data = inner_join(expressionData, proteinData)
dim(data)
head(arrange(data, normalized_count))

#' 
#' The dimension of the resulting table should match the number of observations indicated in our original BigQuery result, and now we perform a Spearman correlation on the two data vectors:
#' 
## ------------------------------------------------------------------------
cor(x=data$normalized_count, y=data$protein_expression, method="spearman")
qplot(data=data, y=log2(normalized_count), x=protein_expression, geom=c("point","smooth"),
      xlab="protein level", ylab="log2 mRNA level")

#' 
#' The R-based Spearman correlation matches the BigQuery result.
#' 
#' ## Provenance
## ----provenance, comment=NA----------------------------------------------
sessionInfo()

