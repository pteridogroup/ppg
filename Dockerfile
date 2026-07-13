FROM rocker/verse:4.5.0

ARG DEBIAN_FRONTEND=noninteractive

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

# Leave default user as root so the entrypoint can fix bind-mount ownership
USER root
WORKDIR /wd

# Add entrypoint script to fix permissions on container start
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Interactive shell for local development
CMD ["bash"]