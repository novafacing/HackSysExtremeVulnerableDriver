#
# Windows Driver Builder using WDK
#
# Modified from: https://github.com/SergiusTheBest/FindWDK
#

# clear some flags
set(CMAKE_C_FLAGS "")
set(CMAKE_C_FLAGS_RELEASE "")
set(CMAKE_CREATE_CONSOLE_EXE "")
set(CMAKE_CREATE_WIN32_EXE "")
set(CMAKE_C_STANDARD_LIBRARIES "")


# find Windows Kits root path from registry
get_filename_component(
    KITS_ROOT
    "[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows Kits\\Installed Roots;KitsRoot10]"
    ABSOLUTE
    CACHE
)

# find ntddk.h
if(KITS_ROOT)
    file(GLOB WDK_NTDDK_FILES "${KITS_ROOT}/Include/*/km/ntddk.h")
elseif(DEFINED $ENV{WDKContentRoot})
    file(GLOB WDK_NTDDK_FILES "$ENV{WDKContentRoot}/Include/*/km/ntddk.h")
else()
    file(GLOB WDK_NTDDK_FILES "C:/Program Files*/Windows Kits/*/Include/*/km/ntddk.h")
endif()

if(WDK_NTDDK_FILES)
    list(GET WDK_NTDDK_FILES -1 WDK_LATEST_NTDDK_FILE)
endif()


include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(WDK REQUIRED_VARS WDK_LATEST_NTDDK_FILE)

if (NOT WDK_LATEST_NTDDK_FILE)
    message(FATAL_ERROR "Unable to locate ntddk.h")
    return()
endif()

# get WDK version and root path
get_filename_component(WDK_ROOT ${WDK_LATEST_NTDDK_FILE} DIRECTORY)
get_filename_component(WDK_ROOT ${WDK_ROOT} DIRECTORY)
get_filename_component(WDK_VERSION ${WDK_ROOT} NAME)
get_filename_component(WDK_ROOT ${WDK_ROOT} DIRECTORY)
get_filename_component(WDK_ROOT ${WDK_ROOT} DIRECTORY)

message(STATUS "WDK_ROOT: ${WDK_ROOT}")
message(STATUS "WDK_VERSION: ${WDK_VERSION}")

# location of warning.h
set(WDK_WARNING_H_FILE "${WDK_ROOT}/Include/${WDK_VERSION}/shared/warning.h")
set(WDK_COMPILE_FLAGS
    "/Zi"
    "/W4"
    "/WX"
    "/diagnostics:classic"
    "/Ox"
    "/Os"
    "/Oy-"
    "/GF"
    "/Gm-"
    "/Zp8"
    "/GS"
    "/Gy"
    "/fp:precise"
    "/Zc:wchar_t-"
    "/Zc:forScope"
    "/Zc:inline"
    "/GR-"
    "/wd4603"
    "/wd4627"
    "/wd4986"
    "/wd4987"
    "/wd4996"
    "/FC"
    "/errorReport:prompt"
    "/kernel"
    "-cbstring"
    "/d1nodatetime"
    "/d1import_no_registry"
    "/d2AllowCompatibleILVersions"
    "/d2Zi+"
    "/Qspectre"
    "/FI${WDK_WARNING_H_FILE}"
)
set(WDK_WINVER "0x0601" CACHE STRING "Default WINVER for WDK targets")
set(WDK_COMPILE_DEFINITIONS "WINNT=1;NTDDI_VERSION=0x06010000;WINVER=${WDK_WINVER}")
set(WDK_COMPILE_DEFINITIONS_DEBUG "MSC_NOOPT;DEPRECATE_DDK_FUNCTIONS=1;DBG=1")

# adjust the comile definitions depending on the compile target architecture
if(HOST_ARCH_X86)
    list(APPEND WDK_COMPILE_FLAGS "/Gz")
    list(APPEND WDK_COMPILE_DEFINITIONS "_X86_=1;i386=1;STD_CALL;")
elseif(HOST_ARCH_X64)
    list(APPEND WDK_COMPILE_FLAGS "/Gz")
    list(APPEND WDK_COMPILE_FLAGS "-d2epilogunwind")
    list(APPEND WDK_COMPILE_DEFINITIONS "_WIN64;_AMD64_;AMD64;")
elseif(HOST_ARCH_ARM64)
    list(APPEND WDK_COMPILE_DEFINITIONS "_ARM64_;ARM64;_USE_DECLSPECS_FOR_SAL=1;STD_CALL;")
else()
    message(FATAL_ERROR "Unsupported architecture")
    return()
endif()

string(CONCAT WDK_LINK_FLAGS
    "/MANIFEST:NO "
    "/PROFILE "
    "/RELEASE "
    "/DEBUG "
    "/WX "
    "/Driver "
    "/OPT:REF "
    "/OPT:ICF "
    "/INCREMENTAL:NO "
    "/SUBSYSTEM:NATIVE,6.01 "
    "/MERGE:_TEXT=.text;_PAGE=PAGE "
    "/NODEFAULTLIB "
    "/SECTION:INIT,d "
    "/kernel "
    "/IGNORE:4198,4010,4037,4039,4065,4070,4078,4087,4089,4221,4108,4088,4218,4218,4235 "
    "/osversion:10.0 "
    "/pdbcompress "
    "/debugtype:pdata "
)

# Generate imported targets for WDK lib files
file(GLOB WDK_KM_LIBS "${WDK_ROOT}/Lib/${WDK_VERSION}/km/${HOST_PLATFORM}/*.lib")
file(GLOB WDK_UM_LIBS "${WDK_ROOT}/Lib/${WDK_VERSION}/um/${HOST_PLATFORM}/*.lib")

foreach(LIBRARY IN LISTS WDK_KM_LIBS)
    get_filename_component(LIBRARY_NAME ${LIBRARY} NAME_WLE)
    string(TOUPPER ${LIBRARY_NAME} LIBRARY_NAME)
    add_library(WDK_KM::${LIBRARY_NAME} INTERFACE IMPORTED)
    set_property(TARGET WDK_KM::${LIBRARY_NAME} PROPERTY INTERFACE_LINK_LIBRARIES ${LIBRARY})
endforeach(LIBRARY)

foreach(LIBRARY IN LISTS WDK_UM_LIBS)
    get_filename_component(LIBRARY_NAME ${LIBRARY} NAME_WLE)
    string(TOUPPER ${LIBRARY_NAME} LIBRARY_NAME)
    add_library(WDK_UM::${LIBRARY_NAME} INTERFACE IMPORTED)
    set_property(TARGET WDK_UM::${LIBRARY_NAME} PROPERTY INTERFACE_LINK_LIBRARIES ${LIBRARY})
endforeach(LIBRARY)

unset(WDK_KM_LIBS)
unset(WDK_UM_LIBS)

function(wdk_add_driver _target)
    cmake_parse_arguments(WDK "" "WDM;PFX_FILE;PFX_PASSWORD" "" ${ARGN})

    add_executable(${_target} ${WDK_UNPARSED_ARGUMENTS})

    set_target_properties(${_target} PROPERTIES SUFFIX ".sys")
    set_target_properties(${_target} PROPERTIES COMPILE_OPTIONS "${WDK_COMPILE_FLAGS}")
    set_target_properties(${_target} PROPERTIES COMPILE_DEFINITIONS
        "${WDK_COMPILE_DEFINITIONS};$<$<CONFIG:Debug>:${WDK_COMPILE_DEFINITIONS_DEBUG}>;_WIN32_WINNT=${WDK_WINVER}"
    )
    set_target_properties(${_target} PROPERTIES LINK_FLAGS "${WDK_LINK_FLAGS}")
    set_target_properties(${_target} PROPERTIES VERSION "${HEVD_VERSION}")

    target_include_directories(${_target} SYSTEM PRIVATE
        "${WDK_ROOT}/Include/${WDK_VERSION}/shared"
        "${WDK_ROOT}/Include/${WDK_VERSION}/km"
    )

    target_link_libraries(${_target} WDK_KM::NTOSKRNL WDK_KM::HAL WDK_KM::WMILIB)

    if(HOST_ARCH_X86)
        target_link_libraries(${_target} WDK_KM::BUFFEROVERFLOWK WDK_KM::MEMCMP)
    elseif(HOST_ARCH_X64)
        target_link_libraries(${_target} WDK_KM::BUFFEROVERFLOWK)
    elseif(HOST_ARCH_ARM64)
        target_link_libraries(${_target} WDK_KM::BUFFEROVERFLOWFASTFAILK WDK_UM::ARM64RT)
    endif()

    if(HOST_ARCH_X86)
        set_property(TARGET ${_target} APPEND_STRING PROPERTY LINK_FLAGS "/ENTRY:GsDriverEntry@8")
    elseif(HOST_ARCH_X64)
        set_property(TARGET ${_target} APPEND_STRING PROPERTY LINK_FLAGS "/ENTRY:GsDriverEntry")
    elseif(HOST_ARCH_ARM64)
        set_property(TARGET ${_target} APPEND_STRING PROPERTY LINK_FLAGS "/ENTRY:GsDriverEntry")
    else()
        message(FATAL_ERROR "Unsupported architecture")
        return()
    endif()

    set(PROJECT_INF_PATH "${PROJECT_SOURCE_DIR}\\${CMAKE_PROJECT_NAME}\\${CMAKE_SYSTEM_NAME}\\${CMAKE_PROJECT_NAME}.inf")
    set(PROJECT_PFX_PATH "${PROJECT_SOURCE_DIR}\\${CMAKE_PROJECT_NAME}\\${CMAKE_SYSTEM_NAME}\\${WDK_PFX_FILE}")

    message(STATUS "PROJECT_INF_PATH: ${PROJECT_INF_PATH}")
    message(STATUS "PROJECT_PFX_PATH: ${PROJECT_PFX_PATH}")

    # stampinf.exe Configuration
    set(STAMPINF_PATH "${WDK_ROOT}/bin/${WDK_VERSION}/x86/stampinf.exe")

    if(HOST_ARCH_X86)
        set(STAMPINF_ARGS "-k \"1.9\" -d \"*\" -a \"x86\" -v \"${HEVD_VERSION}\" -f ")
    elseif(HOST_ARCH_X64)
        set(STAMPINF_ARGS "-k \"1.9\" -d \"*\" -a \"amd64\" -v \"${HEVD_VERSION}\" -f ")
    elseif(HOST_ARCH_ARM64)
        set(STAMPINF_ARGS "-k \"1.9\" -d \"*\" -a \"arm64\" -v \"${HEVD_VERSION}\" -f ")
    endif()

    add_custom_command(
      COMMENT "Copying inf to build directory"
      TARGET ${_target}
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different ${PROJECT_INF_PATH} ${CMAKE_CURRENT_BINARY_DIR}
      VERBATIM
    )

    add_custom_command(
      COMMENT "Copying sys to build directory"
      TARGET ${_target}
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CMAKE_CURRENT_BINARY_DIR}\\Release\\${CMAKE_PROJECT_NAME}.sys" ${CMAKE_CURRENT_BINARY_DIR}
      VERBATIM
    )

    add_custom_command(
      COMMENT "Stamping driver inf file"
      TARGET ${_target}
      POST_BUILD
      COMMAND ${STAMPINF_PATH} ${STAMPINF_ARGS} "${CMAKE_CURRENT_BINARY_DIR}\\${CMAKE_PROJECT_NAME}.inf"
    )

    # sign the files if certificate is available
    if(EXISTS ${PROJECT_PFX_PATH})
        # signtool.exe Configuration
        if (HOST_ARCH_X86)
          set(SIGNTOOL_PATH "${WDK_ROOT}/bin/${WDK_VERSION}/x86/signtool.exe")
        elseif(HOST_ARCH_X64)
          set(SIGNTOOL_PATH "${WDK_ROOT}/bin/${WDK_VERSION}/x64/signtool.exe")
        elseif(HOST_ARCH_ARM64)
          set(SIGNTOOL_PATH "${WDK_ROOT}/bin/${WDK_VERSION}/arm64/signtool.exe")
        endif()
        set(SIGNTOOL_ARGS "sign /fd SHA256 /f \"${PROJECT_PFX_PATH}\" /p ${WDK_PFX_PASSWORD}")

        add_custom_command(
          COMMENT "Signing driver binary file"
          TARGET ${_target}
          POST_BUILD
          COMMAND ${SIGNTOOL_PATH} ${SIGNTOOL_ARGS} "${CMAKE_CURRENT_BINARY_DIR}\\${CMAKE_PROJECT_NAME}.sys"
        )
    
        # inf2cat Configuration
        set(INF2CAT_PATH "${WDK_ROOT}/bin/${WDK_VERSION}/x86/inf2cat.exe")

        if(HOST_ARCH_ARM64)
            set(INF2CAT_ARGS "/os:\"10_RS3_ARM64\" /driver:\"${CMAKE_CURRENT_BINARY_DIR}\"")
        else()
            set(INF2CAT_ARGS "/os:\"7_${HOST_PLATFORM}\" /driver:\"${CMAKE_CURRENT_BINARY_DIR}\"")
        endif()

        add_custom_command(
          COMMENT "Creating catalog file"
          TARGET ${_target}
          POST_BUILD
          COMMAND ${INF2CAT_PATH} ${INF2CAT_ARGS}
        )

        add_custom_command(
          COMMENT "Signing driver catalog file"
          TARGET ${_target}
          POST_BUILD
          COMMAND ${SIGNTOOL_PATH} ${SIGNTOOL_ARGS} "${CMAKE_CURRENT_BINARY_DIR}\\${CMAKE_PROJECT_NAME}.cat"
        )

    endif()

endfunction()
