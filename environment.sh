addPath() {
    if [[ ":$PATH:" != *":$1:"* ]]; then
        export PATH="$1:$PATH"
    fi
}

addLib() {
    if [[ ":$LD_LIBRARY_PATH:" != *":$1:"* ]]; then
        export LD_LIBRARY_PATH="$1:$LD_LIBRARY_PATH"
    fi
}
export HDF5_PATH=/usr/local/hdf5
export NETCDF_PATH=/usr/local/netcdf
export NETCDF_C_PATH=/usr/local/netcdf
addPath $HDF5_PATH/bin
addLib $HDF5_PATH/lib
addPath $NETCDF_PATH/bin
addLib $NETCDF_PATH/lib
gxport PS1='\[\033[0;32m\]\[\033[0m\033[0;32m\]\u\[\033[0;34m\]@\[\033[0;34m\]\h \w\n\[\033[0;32m\]>>> \[\033[0m\]'
