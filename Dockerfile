FROM nvcr.io/nvidia/nvhpc:23.9-devel-cuda_multi-ubuntu22.04
LABEL maintainer.name="Peter Schwartz" \
      maintainer.email="schwartzpd@ornl.gov"
# Set a few variables that can be used to control the docker build
# TODO: actually use these to allow for argument builds OR
# remove if its not relevant
ARG ZLIB_VERSION=1.3.1
ARG EXPAT_VERSION=2.4.7 
ARG HDF5_VERSION_MAJOR=1.14
ARG HDF5_VERSION_STRING=1.14.4-2
ARG NETCDF_C_VERSION=4.9.2 
ARG NETCDF_FORTRAN_VERSION=4.6.1 
ARG NETCDF_CXX_VERSION=4.3.1 
ARG NV_VERSION=23.9
# Set directories 
ARG ZLIB_DIR=/usr/local/zlib 
ARG HDF5_DIR=/usr/local/hdf5
ARG NETCDF_DIR=/usr/local/netcdf

# set path variables
ENV PATH=/usr/local/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/lib64:$LD_LIBRARY_PATH

# Update the system and install initial dependencies
RUN apt-get update -y && \
    apt-get install -y \
    automake \
    cmake \
    git \
    subversion \
    bzip2 \
    libgmp3-dev \
    m4 \
    wget \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libncurses5-dev \
    libxml2 \
    libxml2-dev \
    csh \
    liblapack-dev \
    libblas-dev \
    liblapack-dev \
    libxml-libxml-perl \
    libxml2-utils \
    vim \
    libudunits2-0 \
    libudunits2-dev \
    udunits-bin \
    python3 \
    python3-dev \
    python3-pip \
    apt-utils \
    ftp \
    apt-transport-https \
    libssl-dev \
    openssl \
    libncurses5-dev \
    libsqlite3-dev \
    gsl-bin \
    libgsl-dev \
    flex \
    nco \
    locales \
    # Compile Zlib
    && cd / \
    && wget https://www.zlib.net/zlib-$ZLIB_VERSION.tar.gz \
    && tar -xzf zlib-$ZLIB_VERSION.tar.gz \
    && cd zlib-$ZLIB_VERSION  \
    && CFLAGS=-fPIC ./configure --64 --prefix=$ZLIB_DIR \
    && make all && make install  \
    && cd / \
    && rm -rf zlib-$ZLIB_VERSION \
    && rm zlib-$ZLIB_VERSION.tar.gz \
    # Compile Expat
    && wget https://github.com/libexpat/libexpat/releases/download/R_2_4_7/expat-$EXPAT_VERSION.tar.bz2 \
    && tar -xvjf expat-$EXPAT_VERSION.tar.bz2 \
    && cd expat-$EXPAT_VERSION \
    && ./configure && make && make install \
    && cd / \
    && rm -r expat-$EXPAT_VERSION \
    && rm expat-$EXPAT_VERSION.tar.bz2 \
    && apt-get update && apt-get install -y libopenmpi-dev  \
    && pip3 install wheel numpy scipy netCDF4 h5py configparser pyproj rasterio Dask cftime \
    && CFLAGS=-noswitcherror pip3 install mpi4py \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean all

# Add symbolic link python to python3
RUN ln -sf /usr/bin/python3 /usr/bin/python \ 
    ## Install program to configure locales
    && echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen \
    && locale-gen

## Set default locale for the environment
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

## Check locales
RUN locale -a

    ## Add Zlib to the path
ENV LD_LIBRARY_PATH=$ZLIB_DIR/lib:$LD_LIBRARY_PATH
ENV OMPI_ALLOW_RUN_AS_ROOT=1 
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

# Try HDF5 install
# First copy the tarball to the root directory -- faster to wget from host
COPY hdf5-$HDF5_VERSION_STRING.tar.gz \
     netcdf-c-$NETCDF_C_VERSION.tar.gz \
     netcdf-fortran-$NETCDF_FORTRAN_VERSION.tar.gz /

RUN cd / \
    && mkdir -p /usr/local/hdf5 \
    # && wget https://github.com/HDFGroup/hdf5/releases/download/hdf5_1.14.4.2/hdf5-1.14.4-2.tar.gz \
    && tar -zxvf hdf5-$HDF5_VERSION_STRING.tar.gz \
    && mkdir -p build \
    && cd build \ 
    && CC=mpicc FC=mpif90 CXX=mpicxx CFLAGS="-fPIC -O1 -nomp" FCFLAGS="-fPIC -O1 -nomp" FFLAGS="-fPIC -O1 -nomp" \
    ../hdf5-$HDF5_VERSION_STRING/configure --prefix=$HDF5_DIR \
    --enable-fortran --enable-parallel --with-zlib  \
    && make && make install \
    && cd / \
    && rm -rf hdf5-$HDF5_VERSION_STRING \
    && rm -rf build \
    && rm hdf5-$HDF5_VERSION_STRING.tar.gz 

ENV PATH=$HDF5_DIR/bin:$PATH \
    LD_LIBRARY_PATH=$HDF5_DIR/lib:$LD_LIBRARY_PATH

## Install NetCDF-c
RUN cd / \
    && mkdir -p /usr/local/netcdf \ 
    && export NCDIR=/usr/local/netcdf \
    && export HDF5_DIR=/usr/local/hdf5 \
    && export NFDIR=/usr/local/netcdf \
    # && wget https://downloads.unidata.ucar.edu/netcdf-c/$NETCDF_C_VERSION/netcdf-c-$NETCDF_C_VERSION.tar.gz \
    && tar -zxvf netcdf-c-$NETCDF_C_VERSION.tar.gz \
    && cd netcdf-c-$NETCDF_C_VERSION \
    # Long configure command
    &&  CC=`which mpicc` CFLAGS="-fPIC -I${HDF5_DIR}/include" LDFLAGS=-L${HDF5_DIR}/lib \
    ./configure --host=$(./config.guess) --enable-static --enable-shared --enable-netcdf4 \
    --enable-parallel-tests --prefix=${NCDIR} \
    # make and check then install
    && make -j2 all && make check -i && make install \
    && export PATH=$NCDIR/bin:$PATH \
    && export LD_LIBRARY_PATH=$NCDIR/lib:$LD_LIBRARY_PATH \
    && cd / \
    && rm -r netcdf-c-$NETCDF_C_VERSION \
    && rm netcdf-c-$NETCDF_C_VERSION.tar.gz \
    ## Install NetCDF-fortran
    && export NCDIR=/usr/local/netcdf \
    && export HDF5_DIR=/usr/local/hdf5 \
    && export NFDIR=/usr/local/netcdf \
    # && wget https://downloads.unidata.ucar.edu/netcdf-fortran/$NETCDF_FORTRAN_VERSION/netcdf-fortran-$NETCDF_FORTRAN_VERSION.tar.gz \
    && tar -zxvf netcdf-fortran-$NETCDF_FORTRAN_VERSION.tar.gz \
    && cd netcdf-fortran-$NETCDF_FORTRAN_VERSION \
    # Long configure command
    && CC=mpicc FC=mpif90 F77=mpif90 CPP=cpp FFLAGS=-fPIC FCFLAGS=-fPIC \
    CPPFLAGS="-I$NCDIR/include -I$HDF5_DIR/include" LDFLAGS="-L$NCDIR/lib -L$HDF5_DIR/lib" \
    ./configure --host=$(./config.guess) --enable-static --enable-shared --enable-parallel-tests --prefix=$NFDIR \
    # Make and install then clean up
    && make -j2 all && make install \
    && cd / \
    && rm -r netcdf-fortran-$NETCDF_FORTRAN_VERSION \
    && rm netcdf-fortran-$NETCDF_FORTRAN_VERSION.tar.gz


ARG NVARCH=Linux_x86_64
ARG NVCOMPILERS=/opt/nvidia/hpc_sdk
#  PATH=$NVCOMPILERS/$NVARCH/24.3/compilers/bin:$PATH; export PATH
# Add Netcdf to environment 
ENV PATH=$NETCDF_DIR/bin:$PATH \ 
  LD_LIBRARY_PATH=$NETCDF_DIR/lib:$LD_LIBRARY_PATH \
  # Set nvhpc environment variables
  NVARCH=${NVARCH} \
  NVCOMPILERS=${NVCOMPILERS} \
  MANPATH=$MANPATH:$NVCOMPILERS/$NVARCH/$NV_VERSION/compilers/man \ 
  PATH=$NVCOMPILERS/$NVARCH/$NV_VERSION/compilers/bin:$PATH \
  BLASLAPACK_DIR=/opt/nvidia/hpc_sdk/Linux_x86_64/$NV_VERSION/compilers/lib\
  CC_ROOT=/opt/nvidia/hpc_sdk/Linux_x86_64/$NV_VERSION/compilers/ \
  FC_ROOT=/opt/nvidia/hpc_sdk/Linux_x86_64/$NV_VERSION/compilers/ \ 
  PATH=$NVCOMPILERS/$NVARCH/$NV_VERSION/comm_libs/mpi/bin:$PATH \
  MANPATH=$MANPATH:$NVCOMPILERS/$NVARCH/$NV_VERSION/comm_libs/mpi/man \
  # the following is where include & lib under. Although bin is under, the newest bin in in openmpi4/bin/
  MPI_ROOT=/opt/nvidia/hpc_sdk/Linux_x86_64/$NV_VERSION/comm_libs/mpi \
  MPINAME=openmpi \
  PATH=/opt/nvidia/hpc_sdk/bin:$PATH \
  LD_LIBRARY_PATH=/opt/nvidia/hpc_sdk/lib:$LD_LIBRARY_PATH \
  LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH \
  LD_LIBRARY_PATH=/usr/local/cuda/extras/CUPTI/lib64:$LD_LIBRARY_PATH \
  # Set default user 
  USER=modeluser

# Create symbolic link for bash 
RUN ln -sf /usr/bin/bash /usr/bin/sh

