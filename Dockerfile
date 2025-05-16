FROM rocker/verse:4.5.0

ARG DEBIAN_FRONTEND=noninteractive

############################
### Install APT packages ###
############################

# cron for cronjobs
# get list of other deps using R/find_deps.R
# sudo apt install libcurl4-openssl-dev libfontconfig1-dev libfreetype6-dev libglpk-dev libicu-dev libssl-dev libx11-dev libxml2-dev pandoc    

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    cron \
  && apt-get clean

####################################
### Install R packages with renv ###
####################################

# Create directory for renv project library
RUN mkdir /renv

# Set renv library path and enable pak
RUN echo 'Sys.setenv(RENV_PATHS_LIBRARY = "/renv")' >> /usr/local/lib/R/etc/Rprofile.site \
  && echo 'options(renv.config.pak.enabled = TRUE)' >> /usr/local/lib/R/etc/Rprofile.site

# Initialize a 'dummy' project and restore the renv library.
# Since the library path is specified as above, the library will be restored to /renv
RUN mkdir /tmp/project

COPY ./renv.lock /tmp/project

WORKDIR /tmp/project

# Restore, but don't use cache
# Install pak and renv, then restore
RUN Rscript -e 'install.packages(c("pak", "renv")); renv::consent(provided = TRUE); renv::settings$use.cache(FALSE); renv::init(bare = TRUE); renv::restore()'

############
### Cron ###
############

# cron is used to run R/digest.R automatically once per week

# Copy script to run targets::tar_make() from /wd
COPY ./make.sh /home/make.sh

RUN chmod 0644 /home/make.sh

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Setup cron job: Run at 12:00am on Monday
RUN (crontab -l ; echo "0 0 * * 1 bash /home/digest.sh >> /var/log/cron.log 2>&1") | crontab

# To run the cron job, provide the command `cron` to `docker run`:
# docker run --rm -dt -v ${PWD}:/wd -w /wd --name ppg_make --user root joelnitta/ppg:latest cron -f
# 
# as long as the container is up, it will run the job once per week

### User settings ###

# Add generic non-root user
RUN useradd --create-home --shell /bin/bash user

# Set working directory to home of non-root user
WORKDIR /home/user

# Default to non-root (can override with --user at runtime)
USER user
