#!/bin/bash
# Copyright (c) 2019 Advanced Micro Devices, Inc. All rights reserved.

# #################################################
# helper functions
# #################################################
function display_help()
{
    echo "RCCL build & installation helper script"
    echo "./install [-h|--help] "
    echo "    [-h|--help] prints this help message."
    echo "    [-p|--package_build] Build RCCL package."
    echo "    [-t|--tests_build] Build unit tests, but do not run."
    echo "    [-r|--run_tests] Run unit tests (must be built already.)"
    echo "    [--prefix] Specify custom directory to install RCCL to (default: /opt/rocm/rccl)."
}

# #################################################
# global variables
# #################################################
build_package=false
install_prefix=/opt/rocm/rccl
build_tests=false
run_tests=false
run_tests_only=false
build_release=true
install_library=false
# #################################################
# Parameter parsing
# #################################################

# check if we have a modern version of getopt that can handle whitespace and long parameters
getopt -T
if [[ $? -eq 4 ]]; then
    GETOPT_PARSE=$(getopt --name "${0}" --longoptions help,package_build_only,tests_build,run_tests,prefix: --options hptr -- "$@")
else
    echo "Need a new version of getopt"
    exit 1
fi

if [[ $? -ne 0 ]]; then
    echo "getopt invocation failed; could not parse the command line";
    exit 1
fi

eval set -- "${GETOPT_PARSE}"

while true; do
    case "${1}" in
	-h|--help)
        display_help
        exit 0
        ;;
        -i|--install)
            install_library=true
            shift ;;
	-p|--package_build)
            build_package=true
	    shift ;;
	-t|--tests_build)
	    build_tests=true
	    shift ;;
	-r|--run_tests)
	    run_tests=true
	    shift ;;
    --prefix)
        install_prefix=${2}
        shift 2 ;;
	--) shift ; break ;;
	*)  echo "Unexpected command line parameter received; aborting";
	    exit 1
	    ;;
    esac
    done

# Install the pre-commit hook
#bash ./githooks/install

rocm_path=/opt/rocm/bin
#build_dir=./build
# #################################################
# prep
# #################################################
# ensure a clean build environment
if [[ "${build_release}" == true ]]; then
    rm -rf ${build_dir}/release
else
    rm -rf ${build_dir}/debug
fi


# Create and go to the build directory.
mkdir -p build; cd build

if ($build_release); then
    mkdir -p release; cd release
else
    mkdir -p debug; cd debug
fi


# build type
if [[ "${build_release}" == true ]]; then
    #mkdir -p ${build_dir}/release/clients && cd ${build_dir}/release
    cmake_common_options="${cmake_common_options} -DCMAKE_BUILD_TYPE=Release"
else
    #mkdir -p ${build_dir}/debug/clients && cd ${build_dir}/debug
    cmake_common_options="${cmake_common_options} -DCMAKE_BUILD_TYPE=Debug"
fi


#if !($run_tests_only); then
#    cd build

if ($build_tests); then
    CXX=$rocm_path/hcc cmake -DBUILD_TESTS=ON -DCMAKE_INSTALL_PREFIX=$install_prefix ../../.
else
    CXX=$rocm_path/hcc cmake -DBUILD_TESTS=OFF -DCMAKE_INSTALL_PREFIX=$install_prefix ../../.
fi

make -j$(nproc)

    if ($build_package); then
        make package
    fi
#fi

# Optionally, run tests if they're enabled.
if ($run_tests); then
    if (test -f "./test/UnitTests"); then
        HSA_FORCE_FINE_GRAIN_PCIE=1 ./test/UnitTests
    else
        echo "Unit tests have not been built yet; please re-run script with -t to build unit tests."
        exit 1
    fi
fi