---
title: "Pulling down small matrices"
author: "David L Gibbs"
date: "March 28, 2016"
output: html_document
---

The goal is to use a predifined cohort, and a gene set, along with bigquery to create a small matrix of gene expression.

If you don't have our ISBCGCExamples, check out https://github.com/isb-cgc/examples-R


```r
library(ISBCGCExamples)
library(stringr)
library(dplyr)
```

Let's suppose you've already created a cohort using the web-app or "save_cohorts" R function.
Earlier, I created a cohort of all TCGA samples from brain tissue. I'll use the cohort functions to wrangle that data.


```r
mytoken <- isb_init()       # get authorized

mycohorts <- list_cohorts(mytoken) # get my list of cohorts
```

```
## Auto-refreshing stale OAuth token.
```

```r
mycohorts$count             # number of cohorts I've saved (3)
```

```
## [1] "3"
```

```r
mycohorts$items[[2]]$name   # name of the cohort
```

```
## [1] "brain_age_10_to_39"
```

```r
mycohorts$items[[2]]$id     # ID number of the cohort.
```

```
## [1] "69"
```

To get the list of barcodes, use the barcodes_from_cohort function,
substituting the cohort ID.  Your cohort IDs are found in the list_cohorts
output.


```r
mytoken <- isb_init()       # get authorized
barcodes  <- barcodes_from_cohort("69", mytoken)
barcodes$sample_count # number of samples available
```

```
## [1] "126"
```

barcodes is a list with both sample and patient barcodes, and counts of both.


```r
sample_barcodes <- unlist(barcodes$samples)
```

Secondly, let's suppose you have a list of genes in a file.. on your desktop.


```r
gene_table <- read.table("notch_pathway_genes.txt", sep="\t", header=T, stringsAsFactors=F)
notch_genes <- gene_table$Gene.Name
```

Now we'll build the query. I'm first going to define a helper function
that creates lists of things in the SQL format.


```r
qlist <- function(g) {
  x <- sapply(g, function(gi) paste("\'", gi, "\'", sep=""))
  y <- c()
  for(i in 1:(length(g)-1)){
    y <- c(y, x[i], ",")
  }
  y <- c(y, x[length(x)])
  z <- paste(y, collapse="")
  paste0('(', z, ')')
}
```

Now depending on whether you want to work with ParticipantBarcodes
or SampleBarcodes, you can modify the below query.


```r
require(bigrquery) || install.packages("bigrquery")
```

```
## [1] TRUE
```

```r
querySql <- paste0("
SELECT
  ParticipantBarcode,
  SampleBarcode,
  Study,
  HGNC_gene_symbol as gene_symbol,
  LOG2(normalized_count+1) AS log2_expr
FROM
  [isb-cgc:tcga_201510_alpha.mRNA_UNC_HiSeq_RSEM]
WHERE
  ( SampleTypeLetterCode='TP'
    AND HGNC_gene_symbol in ", qlist(notch_genes), "
    AND SampleBarcode in ", qlist(sample_barcodes), "
   )
GROUP BY
ParticipantBarcode,
SampleBarcode,
Study,
gene_symbol,
log2_expr
")
result <- query_exec(querySql, project=project)
```

Then we just have to convert the table to a matrix.


```r
library(tidyr)

data_matrix <- result %>% select(SampleBarcode, gene_symbol, log2_expr)  %>%
    group_by(SampleBarcode, gene_symbol) %>%
    mutate(row=1:n()) %>%
    spread(gene_symbol, log2_expr)
```

Now we have a data frame of gene expression for downstream processing.
