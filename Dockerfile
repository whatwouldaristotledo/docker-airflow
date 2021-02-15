# VERSION 1.10.9
# AUTHORS: Matthieu "Puckel_" Roisil for docker-airflow container, Aristotle added Oracle and MSSQL drivers
# DESCRIPTION: Basic Airflow container with MSSQL SERVER DRIVER AND ORACLE DRIVER
# BUILD: docker build --rm -t puckel/docker-airflow .
# SOURCE: https://github.com/puckel/docker-airflow

FROM python:3.7-slim-buster
LABEL maintainer="Aristotle"

########################################
#### BEGIN:  MICROSOFT ODBC DRIVER
######################################
RUN apt-get update && \
      apt-get -y install sudo
RUN apt-get update && apt-get install -y \
curl
RUN apt-get install -y gnupg2
RUN apt-get install -y wget
# UPDATE APT-GET
RUN apt-get update

# PYODBC DEPENDENCES
RUN apt-get install -y tdsodbc unixodbc-dev
RUN apt install unixodbc-bin -y
RUN apt-get clean -y
ADD odbcinst.ini /etc/odbcinst.ini
#ADD odbc.ini /etc/odbc.ini

# UPGRADE pip3
RUN pip3 install --upgrade pip

# DEPENDECES FOR DOWNLOAD ODBC DRIVER
RUN apt-get install apt-transport-https 
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list
RUN apt-get update

# INSTALL ODBC DRIVER
RUN ACCEPT_EULA=Y apt-get install msodbcsql17 --assume-yes
RUN ACCEPT_EULA=Y apt-get install mssql-tools --assume-yes
# CONFIGURE ENV FOR /bin/bash TO USE MSODBCSQL17
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile 
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc 


########################################
#### END: MICROSOFT ODBC DRIVER
########################################

########################################
#### BEGIN ORACLE INSTANT CLIENT TOOLS
########################################
RUN apt-get update \
    && apt-get -y install unzip \
    && apt-get -y install libaio-dev \
    && mkdir -p /opt/data/api


WORKDIR /opt/data
ADD ./oracle-instantclient/ /opt/data
ADD ./install-instantclient.sh /opt/data
ADD ./requirements.txt /opt/data

ENV ORACLE_HOME=/opt/oracle/instantclient
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME

ENV OCI_HOME=/opt/oracle/instantclient
ENV OCI_LIB_DIR=/opt/oracle/instantclient
ENV OCI_INCLUDE_DIR=/opt/oracle/instantclient/sdk/include

# INSTALL INSTANTCLIENT AND DEPENDENCIES
RUN ./install-instantclient.sh
#RUN pip install -r requirements.txt
### run this for pyodbc
RUN apt-get update && apt-get install -y --no-install-recommends \
    unixodbc-dev \
    unixodbc \
    libpq-dev 

########################################
#### END ORACLE INSTANT CLIENT TOOLS
########################################

 

# Never prompt the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

# Airflow
ARG AIRFLOW_VERSION=1.10.9
ARG AIRFLOW_USER_HOME=/usr/local/airflow
ARG AIRFLOW_DEPS=""
ARG PYTHON_DEPS=""
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}

# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

# Disable noisy "Handling signal" log messages:
# ENV GUNICORN_CMD_ARGS --log-level WARNING

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && useradd -ms /bin/bash -d ${AIRFLOW_USER_HOME} airflow \
    && pip install -U pip setuptools wheel \
    && pip uninstall -y SQLAlchemy \
    && pip install SQLAlchemy==1.3.15 \
    && pip install pytz \
    && apt-get update \
    && apt-get install -y gnupg2 \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install pyodbc \
    && pip install cx_oracle \
    && pip install apache-airflow[crypto,celery,postgres,hive,jdbc,mysql,ssh${AIRFLOW_DEPS:+,}${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
    && pip install 'redis==3.2' \
    && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base




COPY script/entrypoint.sh /entrypoint.sh
COPY config/airflow.cfg ${AIRFLOW_USER_HOME}/airflow.cfg



RUN chown -R airflow: ${AIRFLOW_USER_HOME}

EXPOSE 8080 5555 8793

USER airflow
WORKDIR ${AIRFLOW_USER_HOME}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["webserver"]
