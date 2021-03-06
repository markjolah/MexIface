# mexiface_configure_install.cmake
# Copyright 2018
# Author: Mark J. Olah
# Email: (mjo@cs.unm DOT edu)
#
# Sets up a ${PROJECT_NAME}config-mexiface.cmake file for passing MexIFace and Matlab configuration to dependencies
# Installs Matlab code and startup${PROJECT_NAME}.m file for Matlab integration, which is able to run dependent startup.m file
# from DEPENDENCY_STARTUP_M_LOCATIONS
#
# Configures a build-tree export which enables editing of the sources .m files in-repository. [EXPORT_BUILD_TREE True]
#
# Options:
#  NOMEX - Disable MEX. This flag should be added by packages that export Matlab code only, no MEX modules.
# Single Argument Keywords:
#  CONFIG_DIR - [Default: ${CMAKE_BINARY_DIR}] Path within build directory to make configured files before installation.  Also serves as the exported build directory.
#  PACKAGE_CONFIG_MEXIFACE_TEMPLATE -  [Default: ../Templates/PackageConfig-mexiface.cmake.in] Template file for package config.
#  PACKAGE_CONFIG_MATLAB_ARCH_TEMPLATE -  [Default: ../Templates/PackageConfig-Matlab-Arch.cmake.in] Template file for arch dependent Matlab package config.
#  CONFIG_INSTALL_DIR - [Default: lib/cmake/${PROJECT_NAME}] Relative path from ${CMAKE_INSTALL_PREFIX} at which to install PackageConfig.cmake files
#  MATLAB_SRC_DIR - [Default: matlab] relative to ${CMAKE_SOURCE_DIR}
#  STARTUP_M_TEMPLATE - [Default: ${CMAKE_CURRENT_LIST_DIR}/../[Templates|templates]/startupPackage.m.in
#  STARTUP_M_FILE - [Default: startup${PROJECT_NAME}.m
#  MATLAB_CODE_INSTALL_DIR - [Default: lib/${PROJECT_NAME}/matlab] Should be relative to CMAKE_INSTALL_PREFIX
#  MATLAB_MEX_INSTALL_DIR - [Default: lib/${PROJECT_NAME}/mex] Should be relative to CMAKE_INSTALL_PREFIX
#  EXPORT_BUILD_TREE - Bool. [optional] [Default: False] - Enable the export of the build tree. And configuration of startup<PROJECT_NAME>.cmake
#                        script that can be used from the build tree.  For development.
# Multi-Argument Keywords:
#  DEPENDENCY_STARTUP_M_LOCATIONS - Paths for .m files that this package depends on.  Should be relative to CMAKE_INSTALL_PREFIX, or absolute for files outside the install prefix
#                                   (normally this only makes sense when using from the build directory for development)

set(_mexiface_configure_install_PATH ${CMAKE_CURRENT_LIST_DIR})
function(mexiface_configure_install)
    set(options NOMEX)
    set(oneValueArgs CONFIG_DIR PACKAGE_CONFIG_MEXIFACE_TEMPLATE PACKAGE_CONFIG_MATLAB_ARCH_TEMPLATE
                     CONFIG_INSTALL_DIR MATLAB_SRC_DIR STARTUP_M_TEMPLATE STARTUP_M_FILE
                     MATLAB_CODE_INSTALL_DIR MATLAB_MEX_INSTALL_DIR EXPORT_BUILD_TREE)
    set(multiValueArgs DEPENDENCY_STARTUP_M_LOCATIONS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}"  ${ARGN})
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unknown keywords given to mexiface_configure_install(): \"${_SVF_UNPARSED_ARGUMENTS}\"")
    endif()
    if(NOT ARG_CONFIG_DIR)
        set(ARG_CONFIG_DIR ${CMAKE_BINARY_DIR})
    endif()

    if(NOT ARG_PACKAGE_CONFIG_MEXIFACE_TEMPLATE)
        find_file(ARG_PACKAGE_CONFIG_MEXIFACE_TEMPLATE PackageConfig-mexiface.cmake.in
                PATHS ${_mexiface_configure_install_PATH}/../Templates NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
        mark_as_advanced(ARG_PACKAGE_CONFIG_MEXIFACE_TEMPLATE)
        if(NOT ARG_PACKAGE_CONFIG_MEXIFACE_TEMPLATE)
            message(FATAL_ERROR "Unable to find PackageConfig-mexiface.cmake.in. Cannot configure exports.")
        endif()
    endif()

    if(NOT ARG_PACKAGE_CONFIG_MATLAB_ARCH_TEMPLATE)
        find_file(ARG_PACKAGE_CONFIG_MATLAB_ARCH_TEMPLATE PackageConfig-Matlab-Arch.cmake.in
                PATHS ${_mexiface_configure_install_PATH}/../Templates NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
        mark_as_advanced(ARG_PACKAGE_PACKAGE_CONFIG_MATLAB_ARCH_TEMPLATE)
        if(NOT ARG_PACKAGE_CONFIG_MATLAB_ARCH_TEMPLATE)
            message(FATAL_ERROR "Unable to find PackageConfig-Matlab-Arch.cmake.in Cannot configure Matlab arch dependent export variables.")
        endif()
    endif()

    if(NOT ARG_CONFIG_INSTALL_DIR)
        set(ARG_CONFIG_INSTALL_DIR lib/${PROJECT_NAME}/cmake) #Where to install project Config.cmake and ConfigVersion.cmake files
    endif()

    if(NOT ARG_MATLAB_SRC_DIR)
        set(ARG_MATLAB_SRC_DIR ${CMAKE_SOURCE_DIR}/matlab)
    endif()

    if(NOT ARG_STARTUP_M_TEMPLATE)
        find_file(ARG_STARTUP_M_TEMPLATE startupPackage.m.in
                PATHS ${_mexiface_configure_install_PATH}/../Templates NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
        mark_as_advanced(ARG_PACKAGE_CONFIG_MEXIFACE_TEMPLATE)
        if(NOT ARG_PACKAGE_CONFIG_MEXIFACE_TEMPLATE)
            message(FATAL_ERROR "Unable to find startupPackage.m.in. Cannot configure Matlab package for use by downstream.")
        endif()
    endif()

    if(NOT ARG_STARTUP_M_FILE)
        set(ARG_STARTUP_M_FILE startup${PROJECT_NAME}.m)
    endif()

    if(NOT ARG_MATLAB_CODE_INSTALL_DIR)
        set(ARG_MATLAB_CODE_INSTALL_DIR lib/${PROJECT_NAME}/matlab)
    elseif(IS_ABSOLUTE ARG_MATLAB_CODE_INSTALL_DIR)
        file(RELATIVE_PATH ARG_MATLAB_CODE_INSTALL_DIR ${CMAKE_INSTALL_PREFIX} ${ARG_MATLAB_CODE_INSTALL_DIR})
    endif()

    if(NOT ARG_MATLAB_MEX_INSTALL_DIR)
        set(ARG_MATLAB_MEX_INSTALL_DIR lib/${PROJECT_NAME}/mex)
    elseif(IS_ABSOLUTE ARG_MATLAB_MEX_INSTALL_DIR)
        file(RELATIVE_PATH ARG_MATLAB_MEX_INSTALL_DIR ${CMAKE_INSTALL_PREFIX} ${ARG_MATLAB_MEX_INSTALL_DIR})
    endif()

    if(NOT ARG_DEPENDENCY_STARTUP_M_LOCATIONS)
        set(ARG_DEPENDENCY_STARTUP_M_LOCATIONS)
    endif()
    list(APPEND ARG_DEPENDENCY_STARTUP_M_LOCATIONS ${MexIFace_MATLAB_STARTUP_M})
    list(REMOVE_DUPLICATES ARG_DEPENDENCY_STARTUP_M_LOCATIONS)

    # Set different names for build-tree and install-tree files
    set(ARG_PACKAGE_CONFIG_MEXIFACE_FILE ${PROJECT_NAME}Config-mexiface.cmake)
    if(OPT_EXPORT_BUILD_TREE AND NOT DEFINED ARG_EXPORT_BUILD_TREE)
        set(ARG_EXPORT_BUILD_TREE True)
    endif()

    #Install matlab source
    if(BUILD_TESTING AND (NOT DEFINED OPT_INSTALL_TESTING OR OPT_INSTALL_TESTING))
        set(_EXCLUDE) #
    else()
        set(_EXCLUDE REGEX "\\+Test" EXCLUDE)
    endif()
    install(DIRECTORY matlab/ DESTINATION ${ARG_MATLAB_CODE_INSTALL_DIR} COMPONENT Runtime ${_EXCLUDE})
    unset(_EXCLUDE)

    #install-tree export config @PROJECT_NAME@Config-mexiface.cmake
    include(CMakePackageConfigHelpers)
    set(_MATLAB_CODE_DIR ${ARG_MATLAB_CODE_INSTALL_DIR}) #Set relative to install prefix for configure_package_config_file
    set(_MATLAB_STARTUP_M ${ARG_MATLAB_CODE_INSTALL_DIR}/${ARG_STARTUP_M_FILE})
    configure_package_config_file(${ARG_PACKAGE_CONFIG_MEXIFACE_TEMPLATE} ${ARG_CONFIG_DIR}/PackageConfigInstallTree/${ARG_PACKAGE_CONFIG_MEXIFACE_FILE}
                                    INSTALL_DESTINATION ${ARG_CONFIG_INSTALL_DIR}
                                    PATH_VARS _MATLAB_CODE_DIR _MATLAB_STARTUP_M
                                    NO_CHECK_REQUIRED_COMPONENTS_MACRO)
    install(FILES ${ARG_CONFIG_DIR}/PackageConfigInstallTree/${ARG_PACKAGE_CONFIG_MEXIFACE_FILE}
            DESTINATION ${ARG_CONFIG_INSTALL_DIR} COMPONENT Development)

    #Configure Matlab arch dependent variables  @PROJECT_NAME@Config-Matlab-<ARCH>.cmake
    set(_CONFIG_MATLAB_ARCH_FILE ${PROJECT_NAME}Config-Matlab-${MexIFace_MATLAB_SYSTEM_ARCH}.cmake)
    configure_file(${ARG_PACKAGE_CONFIG_MATLAB_ARCH_TEMPLATE} ${ARG_CONFIG_DIR}/${_CONFIG_MATLAB_ARCH_FILE} @ONLY)
    #message(STATUS "INSTALL: ${ARG_CONFIG_DIR}/${_CONFIG_MATLAB_ARCH_FILE} -> ${ARG_CONFIG_INSTALL_DIR}")
    install(FILES ${ARG_CONFIG_DIR}/${_CONFIG_MATLAB_ARCH_FILE} DESTINATION ${ARG_CONFIG_INSTALL_DIR} COMPONENT Development)

    #startup.m install-tree
    set(_MATLAB_CODE_DIR ".") # Relative to startup<PROJECT_NAME>.m file startup.m
    set(_STARTUP_M_INSTALL_DIR ${ARG_MATLAB_CODE_INSTALL_DIR}) #Install dir relative to install prefix
    if(ARG_NOMEX)
        set(_MATLAB_INSTALLED_MEX_PATH) #Disable MEX exporting in startup.m
    else()
        set(_MATLAB_INSTALLED_MEX_PATH ${ARG_MATLAB_MEX_INSTALL_DIR})
    endif()
    #Remap install time dependent startup.m locations to be relative to startup@PROJECT_NAME@.m location
    set(_DEPENDENCY_STARTUP_M_LOCATIONS)
    file(RELATIVE_PATH _install_rpath "/${ARG_MATLAB_CODE_INSTALL_DIR}" "/")
    foreach(location IN LISTS ARG_DEPENDENCY_STARTUP_M_LOCATIONS)
        string(REGEX REPLACE "^${CMAKE_INSTALL_PREFIX}/" "${_install_rpath}" location ${location})
        list(APPEND _DEPENDENCY_STARTUP_M_LOCATIONS ${location})
    endforeach()
    configure_file(${ARG_STARTUP_M_TEMPLATE} ${ARG_CONFIG_DIR}/PackageConfigInstallTree/${ARG_STARTUP_M_FILE})
    install(FILES ${ARG_CONFIG_DIR}/PackageConfigInstallTree/${ARG_STARTUP_M_FILE}
            DESTINATION ${ARG_MATLAB_CODE_INSTALL_DIR} COMPONENT Runtime)
    if(OPT_MexIFace_INSTALL_DISTRIBUTION_STARTUP)
        #Install a copy of the startup at the root of install-tree for convenience of end MATLAB users
        install(FILES ${ARG_CONFIG_DIR}/PackageConfigInstallTree/${ARG_STARTUP_M_FILE}
                DESTINATION "." COMPONENT Runtime)
    endif()
    unset(_MATLAB_INSTALLED_MEX_PATH)

    if(ARG_EXPORT_BUILD_TREE)
        #build-tree export
        file(RELATIVE_PATH _MATLAB_CODE_DIR ${CMAKE_BINARY_DIR} ${ARG_MATLAB_SRC_DIR}) #Relative to CMAKE_BINARY_DIR
        set(_MATLAB_STARTUP_M ${ARG_CONFIG_DIR}/${ARG_STARTUP_M_FILE})
        if(ARG_EXPORT_BUILD_TREE)
            #build-tree export config @PROJECT_NAME@Config-mexiface.cmake
            configure_package_config_file(${ARG_PACKAGE_CONFIG_MEXIFACE_TEMPLATE} ${ARG_CONFIG_DIR}/${ARG_PACKAGE_CONFIG_MEXIFACE_FILE}
                                        INSTALL_DESTINATION "."
                                        INSTALL_PREFIX ${ARG_CONFIG_DIR}
                                        PATH_VARS _MATLAB_CODE_DIR _MATLAB_STARTUP_M
                                        NO_CHECK_REQUIRED_COMPONENTS_MACRO)
        endif()

        #startup.m build-tree
        set(_STARTUP_M_INSTALL_DIR) #Set to empty in build tree export to signal to startup.m that it is run from build tree
        get_property(_MATLAB_BUILD_MEX_PATHS GLOBAL PROPERTY MexIFace_MODULE_BUILD_DIRS)
        if(NOT _MATLAB_BUILD_MEX_PATHS OR ARG_NOMEX)
            set(_MATLAB_BUILD_MEX_PATHS) #Disable MEX exporting
        endif()
        #Remap build time dependent startup.m locations to be relative to startup@PROJECT_NAME@.m location
        set(_DEPENDENCY_STARTUP_M_LOCATIONS)
        foreach(location IN LISTS ARG_DEPENDENCY_STARTUP_M_LOCATIONS)
            file(RELATIVE_PATH location ${CMAKE_BINARY_DIR} ${location})
            list(APPEND _DEPENDENCY_STARTUP_M_LOCATIONS ${location})
        endforeach()
        configure_file(${ARG_STARTUP_M_TEMPLATE} ${ARG_CONFIG_DIR}/${ARG_STARTUP_M_FILE} @ONLY)
    endif()
endfunction()
