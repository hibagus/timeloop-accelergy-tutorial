FROM ubuntu:18.04 AS builder

ENV BUILD_DIR=/usr/local/src

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               locales \
               git \
               scons \
               python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && if [ ! -d $BUILD_DIR ]; then mkdir $BUILD_DIR; fi

# Set up locale

RUN locale-gen en_US.UTF-8  
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8

# Cacti

WORKDIR $BUILD_DIR

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               g++ \
               libconfig++-dev \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/HewlettPackard/cacti.git \
    && cd cacti \
    && make \
    && chmod -R 777 . \
    && apt-get remove -y \
               g++ \
               libconfig++-dev \
    && apt-get autoremove -y


# Build and install timeloop

WORKDIR $BUILD_DIR

COPY timeloop.patch /tmp

ENV ACCELERGYPATH=/usr/local/bin/

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               g++ \
               libconfig++-dev \
               libboost-dev \
               libboost-iostreams-dev \
               libboost-serialization-dev \
               libyaml-cpp-dev \
               libncurses5-dev \
               libtinfo-dev \
               libgpm-dev \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/NVlabs/timeloop.git \
    && cd ./timeloop/src \
    && ln -s ../pat-public/src/pat . \
    && cd .. \
    && patch -p1 </tmp/timeloop.patch \
    && scons \
    && cp build/timeloop /usr/local/bin \
    && cp build/evaluator /usr/local/bin \
    && apt-get remove -y \
               g++ \
               libconfig++-dev \
               libboost-dev \
               libboost-iostreams-dev \
               libboost-serialization-dev \
               libyaml-cpp-dev \
               libncurses5-dev \
    && apt-get autoremove -y



FROM ubuntu:18.04

ENV BUILD_DIR=/usr/local/src

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
               locales \
               git \
               python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd tutorial \
    && useradd -m -d /home/tutorial -c "Tutorial User Account" -s /usr/sbin/nologin -g tutorial tutorial \
    && if [ ! -d $BUILD_DIR ]; then mkdir $BUILD_DIR; fi

# Set up locale

RUN locale-gen en_US.UTF-8  
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8


# Accelergy

WORKDIR $BUILD_DIR

COPY --from=builder  $BUILD_DIR/timeloop/build/timeloop /usr/local/bin
COPY --from=builder  $BUILD_DIR/timeloop/build/evaluator /usr/local/bin
COPY --from=builder  $BUILD_DIR/cacti/cacti /usr/local/bin
COPY --from=builder  $BUILD_DIR/cacti /usr/local/share/accelergy/estimation_plug_ins/accelergy-cacti-plug-in/cacti

RUN pip3 install setuptools \
    && pip3 install wheel \
    && pip3 install libconf \
    && pip3 install numpy \
    && git clone https://github.com/nelliewu95/accelergy.git \
    && cd accelergy \
    && pip3 install . \
    && cd .. \
    && git clone https://github.com/nelliewu95/accelergy-aladdin-plug-in.git \
    && cd accelergy-aladdin-plug-in \
    && pip3 install . \
    && cd .. \
    && git clone https://github.com/nelliewu95/accelergy-cacti-plug-in.git \
    && cd accelergy-cacti-plug-in \
    && pip3 install . \
    && chmod 777 /usr/local/share/accelergy/estimation_plug_ins/accelergy-cacti-plug-in/cacti \
    && cd ..


COPY ./exercises /usr/local/share/tutorial/exercises

COPY docker-entrypoint.sh /usr/local/bin
ENTRYPOINT ["docker-entrypoint.sh"]

WORKDIR /home/tutorial
CMD ["bash"]
