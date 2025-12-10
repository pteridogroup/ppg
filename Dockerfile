FROM rocker/verse:4.5.0

ARG DEBIAN_FRONTEND=noninteractive

############################
### Install APT packages ###
############################
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       cron \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

####################################
### Install R packages with renv ###
####################################
RUN mkdir /renv
RUN echo 'Sys.setenv(RENV_PATHS_LIBRARY = "/renv")' >> /usr/local/lib/R/etc/Rprofile.site

RUN mkdir /tmp/project
COPY ./renv.lock /tmp/project
WORKDIR /tmp/project
RUN Rscript -e 'install.packages(c("pak","renv")); renv::consent(provided=TRUE); renv::settings$use.cache(FALSE); renv::init(bare=TRUE); renv::restore()'

################
### gnparser ###
################
ENV APP_NAME=gnparser
ENV GNP_VERSION=1.11.6
RUN wget https://github.com/gnames/gnparser/releases/download/v$GNP_VERSION/gnparser-v$GNP_VERSION-linux-x86.tar.gz \
  && tar xf $APP_NAME-v$GNP_VERSION-linux-x86.tar.gz \
  && rm $APP_NAME-v$GNP_VERSION-linux-x86.tar.gz \
  && mv "$APP_NAME" /usr/local/bin/

############
### Cron ###
############
# Place your job script in a predictable, executable path
COPY ./make.sh /usr/local/bin/make.sh
RUN chmod 0755 /usr/local/bin/make.sh

# Log file for cron
RUN touch /var/log/cron.log

################################
### Create host-mapped user  ###
################################
# Build-time args let you match host uid/gid to avoid permission issues
ARG USERNAME=user
ARG UID=1001
ARG GID=1001

# Create group and user with fixed UID/GID
RUN groupadd -g ${GID} ${USERNAME} \
 && useradd  -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME}

# Make sure the user can read site libs and write logs
RUN chown -R ${USERNAME}:${USERNAME} /var/log/cron.log \
 && chmod 0644 /var/log/cron.log

# User crontab: runs daily at midnight as ${USERNAME}
# Option A: per-user crontab (preferred)
RUN crontab -u ${USERNAME} -l 2>/dev/null; \
    echo "0 0 * * * cd /wd && /usr/local/bin/make.sh >> /var/log/cron.log 2>&1" | crontab -u ${USERNAME} -

# Option B (alternative): system cron.d entry with explicit user
# RUN echo '0 0 * * *  '"${USERNAME}"'  cd /wd && /usr/local/bin/make.sh >> /var/log/cron.log 2>&1' \
#     > /etc/cron.d/ppg && chmod 0644 /etc/cron.d/ppg

# Leave default user as root so we can start cron; jobs still run as ${USERNAME}
USER root
WORKDIR /wd

# Add entrypoint script to fix permissions on container start
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Cron in foreground for containerized use
CMD ["cron", "-f"]