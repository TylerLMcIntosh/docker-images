FROM rocker/geospatial:4.6

EXPOSE 8787

ARG CRAN_SNAPSHOT=2026-05-01
ENV CRAN_REPO=https://packagemanager.posit.co/cran/${CRAN_SNAPSHOT}
ENV RSPM=${CRAN_REPO}

# Set CRAN repo for interactive R
RUN echo "options(repos = c(CRAN = Sys.getenv('CRAN_REPO')))" >> /usr/local/lib/R/etc/Rprofile.site

#GH identity
RUN git config --system user.name "Tyler McIntosh" && \
    git config --system user.email "tylermcintosh7@gmail.com"

# Core system packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gh \
        curl \
        ca-certificates \
        cmake \
        unzip \
        pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Additional R packages; this dockerfile orders blocks from core to discretionary to enable layer caching

## Core workflow utilities
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1 \
    here \
    fs \
    cli \
    glue \
    withr \
    yaml \
    jsonlite \
    sessioninfo \
    conflicted \
    remotes \
    pak \
    renv \
    tictoc \
    dplyr \
    tidyr \
    purrr \
    tibble \
    forcats \
    stringr && \
    rm -rf /tmp/downloaded_packages

## Data I/O
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1 \
    readr \
    vroom \
    readxl \
    writexl \
    arrow \
    data.table \
    googledrive \
    httr2 \
    curl && \
    rm -rf /tmp/downloaded_packages

## General statistics/helpers
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1 \
    janitor \
    lubridate \
    performance \
    see \
    insight \
    psych \
    DescTools && \
    rm -rf /tmp/downloaded_packages


## Visualization core
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1  \
    patchwork \
    corrplot \
    viridis \
    scico \
    gt \
    gridExtra \
    tinytable && \
    rm -rf /tmp/downloaded_packages
    #ComplexHeatmap \

## Causal inference
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1  \
    fixest \
    WeightIt \
    cobalt \
    MatchIt \
    fect \
    grf \
    did && \
    rm -rf /tmp/downloaded_packages

## Core Modeling
RUN  install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1  \
    car \
    tidymodels \
    mblm \
    lme4 \
    nlme \
    lmerTest  && \
    rm -rf /tmp/downloaded_packages
    
## Parallel computing
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1  \
    future \
    furrr \
    doFuture \
    foreach \
    doParallel \
    future.apply && \
    rm -rf /tmp/downloaded_packages

## Additional spatial
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1  \
    spatialsample \
    tigris \
    h3jsr \
    exactextractr && \
    rm -rf /tmp/downloaded_packages

## Ecology
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1  \
    vegan && \
    rm -rf /tmp/downloaded_packages

## ML
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1  \
    ranger \
    iml \
    vip \
    pdp \
    fastshap \
    kernelshap \
    hstats \
    shapviz \
    dials \
    xgboost \
    tuneRanger && \
    rm -rf /tmp/downloaded_packages

## Workflow orchestration / pipeline management
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1 \
    targets \
    tarchetypes \
    progressr && \
    rm -rf /tmp/downloaded_packages

# add crewing for parallel processing with targest; add if regularly using
    # crew \
    # crew.cluster \
    # callr 

## Convenience / specific use case
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1  \
    ggridges \
    GGally \
    circlize \
    Hmisc \
    tidysdm \
    compositions && \
    rm -rf /tmp/downloaded_packages

## Additional use case packages - move to convenience / specific use case if using


# Bioconductor install for complexheatmap
# RUN R -q -e 'install.packages("BiocManager", repos = Sys.getenv("CRAN_REPO")); BiocManager::install("ComplexHeatmap", ask = FALSE, update = FALSE)' && \
#     rm -rf /tmp/downloaded_packages

## Heavy / specific use case spatial
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1  \
    gdalcubes \
    spmodel && \
    rm -rf /tmp/downloaded_packages


## Heavy / specific use case modeling
RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled --ncpus -1  \
    glmmTMB && \
    rm -rf /tmp/downloaded_packages


# ## Bayesian - move to heavy / specific use case if using
# RUN install2.r --error --repos ${CRAN_REPO} --skipinstalled \
#     brms \
#     tidybayes \
#     loo \
#     posterior \
#     bayesplot && \
#    rm -rf /tmp/downloaded_packages

# Github packages
RUN R -q -e 'remotes::install_github("grf-labs/sufrep@317be9e73f828aee1a3d5333dfd2dd4594c81607", upgrade = "never")' && \
    rm -rf /tmp/downloaded_packages

# GoCommands for CyVerse
#RUN curl -fsSL https://raw.githubusercontent.com/cyverse/gocommands/main/install_gocmd.sh | bash
RUN curl -fsSL https://raw.githubusercontent.com/cyverse/gocommands/main/install_gocmd.sh | bash && \
    cp /gocmd /usr/local/bin/gocmd && \
    chmod +x /usr/local/bin/gocmd && \
    command -v gocmd