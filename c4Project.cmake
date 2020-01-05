if(NOT _c4_project_included)
set(_c4_project_included ON)

cmake_minimum_required(VERSION 3.11 FATAL_ERROR)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

include(ConfigurationTypes)
include(CreateSourceGroup)
include(c4SanitizeTarget)
include(c4StaticAnalysis)
include(PrintVar)
include(c4CatSources)
include(c4Doxygen)


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# define c4 project settings

set(C4_EXTERN_DIR "$ENV{C4_EXTERN_DIR}" CACHE PATH "the directory where imported projects should be looked for (or cloned in when not found)")
set(C4_DBG_ENABLED OFF CACHE BOOL "enable detailed cmake logs in c4Project code")
set(C4_LIBRARY_TYPE "" CACHE STRING "default library type: either \"\"(defer to BUILD_SHARED_LIBS),INTERFACE,STATIC,SHARED,MODULE")
set(C4_SOURCE_TRANSFORM NONE CACHE STRING "global source transform method")
set(C4_HDR_EXTS "h;hpp;hh;h++;hxx" CACHE STRING "list of header extensions for determining which files are headers")
set(C4_SRC_EXTS "c;cpp;cc;c++;cxx;cu;" CACHE STRING "list of compilation unit extensions for determining which files are sources")
set(C4_GEN_SRC_EXT "cpp" CACHE STRING "the extension of the output source files resulting from concatenation")
set(C4_GEN_HDR_EXT "hpp" CACHE STRING "the extension of the output header files resulting from concatenation")


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

macro(c4_log)
    message(STATUS "${_c4_prefix}: ${ARGN}")
endmacro()


macro(c4_dbg)
    if(C4_DBG_ENABLED)
        message(STATUS "${_c4_prefix}: ${ARGN}")
    endif()
endmacro()


macro(_c4_show_pfx_vars)
    if(NOT ("${ARGN}" STREQUAL ""))
        message(STATUS "prefix vars: ${ARGN}")
    endif()
    print_var(_c4_prefix)
    print_var(_c4_ocprefix)
    print_var(_c4_ucprefix)
    print_var(_c4_lcprefix)
    print_var(_c4_oprefix)
    print_var(_c4_uprefix)
    print_var(_c4_lprefix)
endmacro()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

function(c4_declare_project prefix)
    set(opt0arg  # zero-value macro arguments
        STANDALONE # Declare that targets from this project MAY be
                   # compiled in standalone mode. In this mode, any
                   # designated libraries on which a target depends
                   # will be incorporated into the target instead of
                   # being linked with it. The effect is to "flatten"
                   # those libraries into the requesting library, with
                   # their sources now becoming part of the requesting
                   # library; their dependencies are transitively handled.
                   # Note that requesting targets must explicitly
                   # opt-in to this behavior via the INCORPORATE
                   # argument to c4_add_library() or
                   # c4_add_executable(). Note also that this behavior
                   # is only enabled if this project's option
                   # ${prefix}_STANDALONE or C4_STANDALONE is set to ON.
    )
    set(opt1arg  # one-value macro arguments
        DESC
        AUTHOR
        URL
        MAJOR
        MINOR
        RELEASE
        CXX_STANDARD  # if this is not provided, falls back on
                      # ${uprefix}CXX_STANDARD, then C4_CXX_STANDARD
    )
    set(optNarg  # multi-value macro arguments
        AUTHORS
    )
    cmake_parse_arguments("" "${opt0arg}" "${opt1arg}" "${optNarg}" ${ARGN})
    #
    # get the several prefix flavors
    string(TOUPPER "${prefix}" _c4_ucprefix) # ucprefix := upper case prefix
    string(TOLOWER "${prefix}" _c4_lcprefix) # lcprefix := lower case prefix
    set(_c4_uprefix  ${_c4_ucprefix})        # upper prefix: for variables
    set(_c4_lprefix  ${_c4_lcprefix})        # lower prefix: for targets
    set(_c4_prefix   ${prefix})              # prefix := original prefix
    set(_c4_oprefix  ${prefix})              # oprefix := original prefix
    set(_c4_ocprefix ${prefix})              # ocprefix := original case prefix
    if(_c4_oprefix)
        set(_c4_oprefix "${_c4_oprefix}_")
    endif()
    if(_c4_uprefix)
        set(_c4_uprefix "${_c4_uprefix}_")
    endif()
    if(_c4_lprefix)
        set(_c4_lprefix "${_c4_lprefix}-")
    endif()
    # export the prefixes
    set(_c4_prefix   ${_c4_prefix}   PARENT_SCOPE)
    set(_c4_oprefix  ${_c4_oprefix}  PARENT_SCOPE)
    set(_c4_uprefix  ${_c4_uprefix}  PARENT_SCOPE)
    set(_c4_lprefix  ${_c4_lprefix}  PARENT_SCOPE)
    set(_c4_ocprefix ${_c4_ocprefix} PARENT_SCOPE)
    set(_c4_ucprefix ${_c4_ucprefix} PARENT_SCOPE)
    set(_c4_lcprefix ${_c4_lcprefix} PARENT_SCOPE)
    #
    _c4_handle_arg(DESC "${_c4_lcprefix}")
    _c4_handle_arg(AUTHOR "${_c4_lcprefix} author <author@domain.net>")
    _c4_handle_arg(AUTHORS "${_AUTHOR}")
    _c4_handle_arg(URL "https://c4project.url")
    _c4_handle_arg(MAJOR 0)
    _c4_handle_arg(MINOR 0)
    _c4_handle_arg(RELEASE 1)
    c4_setg(${_c4_uprefix}VERSION "${_MAJOR}.${_MINOR}.${_RELEASE}")
    _c4_handle_arg_or_fallback(CXX_STANDARD "11")
    #
    c4_set_proj_prop(DESC         "${_DESC}")
    c4_set_proj_prop(AUTHOR       "${_AUTHOR}")
    c4_set_proj_prop(URL          "${_URL}")
    c4_set_proj_prop(MAJOR        "${_MAJOR}")
    c4_set_proj_prop(MINOR        "${_MINOR}")
    c4_set_proj_prop(RELEASE      "${_RELEASE}")
    c4_set_proj_prop(CXX_STANDARD "${_CXX_STANDARD}")

    if("${_c4_curr_subproject}" STREQUAL "")
        set(_c4_curr_subproject ${_c4_prefix})
        set(_c4_curr_path ${_c4_prefix})
    endif()

    if(_STANDALONE)
        option(${_c4_uprefix}STANDALONE
            "Enable compilation of opting-in targets from ${_c4_lcprefix} in standalone mode (ie, incorporate subprojects as specified in the INCORPORATE clause to c4_add_library/c4_add_target)" ${_STANDALONE})
    endif()

    option(${_c4_uprefix}DEV "enable development targets: tests, benchmarks, sanitize, static analysis, coverage" OFF)
    cmake_dependent_option(${_c4_uprefix}BUILD_TESTS "build unit tests" ON ${_c4_uprefix}DEV OFF)
    cmake_dependent_option(${_c4_uprefix}BUILD_BENCHMARKS "build benchmarks" ON ${_c4_uprefix}DEV OFF)
    c4_setup_coverage()
    c4_setup_valgrind(${_c4_uprefix}DEV)
    c4_setup_sanitize(${_c4_uprefix}DEV)
    c4_setup_static_analysis(${_c4_uprefix}DEV)
    c4_setup_doxygen(${_c4_uprefix}DEV)

    # CXX standard
    c4_setg(${_c4_uprefix}CXX_STANDARD "${_CXX_STANDARD}")
    if(${_CXX_STANDARD})
        c4_set_cxx(${_CXX_STANDARD})
    endif()

    # these are default compilation flags
    set(${_c4_uprefix}CXX_FLAGS "" CACHE STRING "compilation flags for ${_c4_prefix} targets")
    # these are optional compilation flags
    cmake_dependent_option(${_c4_uprefix}PEDANTIC "Compile in pedantic mode" ON ${_c4_uprefix}DEV OFF)
    cmake_dependent_option(${_c4_uprefix}WERROR "Compile with warnings as errors" ON ${_c4_uprefix}DEV OFF)
    cmake_dependent_option(${_c4_uprefix}STRICT_ALIASING "Enable strict aliasing" ON ${_c4_uprefix}DEV OFF)
    # always append the optional flags to the project's flags
    set(addf)
    if(${_c4_uprefix}PEDANTIC)
        if(MSVC)
            set(addf "${addf} /W4")
        else()
            set(addf "${addf} -Wall -Wextra -Wshadow -pedantic -Wfloat-equal")
        endif()
    endif()
    if(${_c4_uprefix}WERROR)
        if(MSVC)
            set(addf "${addf} /WX")
        else()
            set(addf "${addf} -Werror -pedantic-errors")
        endif()
    endif()
    if(${_c4_uprefix}STRICT_ALIASING)
        if(NOT MSVC)
            set(addf "${addf} -fstrict-aliasing")
        endif()
    endif()
    set(${_c4_uprefix}CXX_FLAGS_OPT "${${_c4_uprefix}CXX_FLAGS_OPT} ${addf}" PARENT_SCOPE)
endfunction(c4_declare_project)


function(c4_set_proj_prop prop value)
    set(C4PROJ_${_c4_prefix}_${prop} ${value})
endfunction()


function(c4_get_proj_prop prop var)
    set(${var} ${C4PROJ_${_c4_prefix}_${prop}} PARENT_SCOPE)
endfunction()


function(c4_set_target_prop target prop value)
    set_target_properties(${target} PROPERTIES C4_TGT_${prop} ${value})
endfunction()


function(c4_get_target_prop target prop var)
    get_target_property(val ${target} C4_TGT_${prop})
    set(${var} ${val} PARENT_SCOPE)
endfunction()



#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------


macro(_c4_handle_arg argname default)
     if("${_${argname}}" STREQUAL "")
         set(_${argname} "${default}")
     else()
         c4_setg(_${argname} "${_${argname}}")
     endif()
endmacro()


macro(_c4_handle_arg_or_fallback argname default)
    if("${_${argname}}" STREQUAL "")
        if("${${_c4_uprefix}${argname}}" STREQUAL "")
            if("${C4_${argname}}" STREQUAL "")
                c4_dbg("handle arg: _${argname}: picking default=${default}")
                c4_setg(_${argname} "${default}")
            else()
                c4_dbg("handle arg: _${argname}: picking C4_${argname}=${C4_${argname}}")
                c4_setg(_${argname} "${C4_${argname}}")
            endif()
        else()
            c4_dbg("handle arg: _${argname}: picking ${uprefix}${argname}=${${uprefix}${argname}}")
            c4_setg(_${argname} "${${_c4_uprefix}${argname}}")
        endif()
    else()
        c4_dbg("handle arg: _${argname}: picking explicit value _${argname}=${_${argname}}")
        #c4_setg(_${argname} "${_${argname}}")
    endif()
endmacro()


function(c4_set_var_tmp var value)
    c4_dbg("tmp-setting ${var} to ${value} (was ${${value}})")
    set(_c4_old_val_${var} ${${var}})
    set(${var} ${value} PARENT_SCOPE)
endfunction()

function(c4_clean_var_tmp var)
    c4_dbg("cleaning ${var} to ${_c4_old_val_${var}} (tmp was ${${var}})")
    set(${var} ${_c4_old_val_${var}} PARENT_SCOPE)
endfunction()

macro(c4_override opt val)
    set(${opt} ${val} CACHE BOOL "" FORCE)
endmacro()


macro(c4_setg var val)
    set(${var} ${val})
    set(${var} ${val} PARENT_SCOPE)
endmacro()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# WIP, under construction
function(c4_proj_get_version dir)

    if("${dir}" STREQUAL "")
        set(dir ${CMAKE_CURRENT_LIST_DIR})
    endif()

    # http://xit0.org/2013/04/cmake-use-git-branch-and-commit-details-in-project/

    # Get the current working branch
    execute_process(COMMAND git rev-parse --abbrev-ref HEAD
        WORKING_DIRECTORY ${dir}
        OUTPUT_VARIABLE ${_c4_uprefix}GIT_BRANCH
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    # Get the latest abbreviated commit hash of the working branch
    execute_process(COMMAND git log -1 --format=%h
        WORKING_DIRECTORY ${dir}
        OUTPUT_VARIABLE ${_c4_uprefix}GIT_COMMIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    # also: git diff --stat
    # also: git diff
    # also: git status --ignored

endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# examples:
# c4_set_cxx(11) # required, no extensions (eg c++11)
# c4_set_cxx(14) # required, no extensions (eg c++14)
# c4_set_cxx(11 EXTENSIONS) # opt-in to extensions (eg, gnu++11)
# c4_set_cxx(14 EXTENSIONS) # opt-in to extensions (eg, gnu++14)
# c4_set_cxx(11 OPTIONAL) # not REQUIRED. no extensions
# c4_set_cxx(11 OPTIONAL EXTENSIONS)
macro(c4_set_cxx standard)
    _c4_handle_cxx_standard_args(${ARGN})
    c4_setg(CMAKE_CXX_STANDARD ${standard})
    c4_setg(CMAKE_CXX_STANDARD_REQUIRED ${_REQUIRED})
    c4_setg(CMAKE_CXX_EXTENSIONS ${_EXTENSIONS})
endmacro()

# examples:
# c4_target_set_cxx(11) # required, no extensions (eg c++11)
# c4_target_set_cxx(14) # required, no extensions (eg c++14)
# c4_target_set_cxx(11 EXTENSIONS) # opt-in to extensions (eg, gnu++11)
# c4_target_set_cxx(14 EXTENSIONS) # opt-in to extensions (eg, gnu++14)
# c4_target_set_cxx(tgt 11 OPTIONAL) # not REQUIRED. no extensions
# c4_target_set_cxx(tgt 11 OPTIONAL EXTENSIONS)
function(c4_target_set_cxx target standard)
    _c4_handle_cxx_standard_args(${ARGN})
    set_target_properties(${target} PROPERTIES
        CXX_STANDARD ${standard}
        CXX_STANDARD_REQUIRED ${_REQUIRED}
        CXX_EXTENSIONS ${_EXTENSIONS})
    target_compile_features(myTarget PUBLIC cxx_std_${standard})
endfunction()


function(c4_target_inherit_cxx_standard target)
    set_target_properties(${target} PROPERTIES
        CXX_STANDARD "${CMAKE_CXX_STANDARD}"
        CXX_STANDARD_REQUIRED "${CMAKE_CXX_STANDARD_REQUIRED}"
        CXX_EXTENSIONS "${CMAKE_CXX_EXTENSIONS}")
    target_compile_features(${target} PUBLIC cxx_std_${CMAKE_CXX_STANDARD})
endfunction()


macro(_c4_handle_cxx_standard_args)
    set(opt0arg
        OPTIONAL
        EXTENSIONS  # eg, prefer c++11 to gnu++11. defaults to OFF
    )
    set(opt1arg)
    set(optNarg)
    cmake_parse_arguments("" "${opt0arg}" "${opt1arg}" "${optNarg}" ${ARGN})
    # default values for args
    set(_REQUIRED ON)
    if(NOT "${_OPTIONAL}" STREQUAL "")
        set(_REQUIRED OFF)
    endif()
    if("${_EXTENSIONS}" STREQUAL "")
        set(_EXTENSIONS OFF)
    endif()
endmacro()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# type can be one of:
#  SUBDIRECTORY: the subproject is located in the given directory name and
#               will be added via add_subdirectory()
#  REMOTE: the subproject is located in a remote repo/url
#          and will be added via c4_import_remote_proj()
#
# examples:
#
# # c4opt requires subproject c4core, as a subdirectory. c4core will be used
# # as a separate library
# c4_require_subproject(c4core
#     SUBDIRECTORY ${C4OPT_EXT_DIR}/c4core
#     )
#
# # c4opt requires subproject c4core, as a remote proj
# c4_require_subproject(c4core
#     REMOTE GIT_REPOSITORY https://github.com/biojppm/c4core GIT_TAG master
#     )
function(c4_require_subproject subproject_name)
    set(options0arg
        INTERFACE
        EXCLUDE_FROM_ALL
    )
    set(options1arg
        SUBDIRECTORY
    )
    set(optionsnarg
        REMOTE
    )
    cmake_parse_arguments("" "${options0arg}" "${options1arg}" "${optionsnarg}" ${ARGN})
    #
    list(APPEND _${_c4_uprefix}_deps ${subproject_name})
    c4_setg(_${_c4_uprefix}_deps ${_${_c4_uprefix}_deps})

    c4_dbg("-----------------------------------------------")
    c4_dbg("requires subproject ${subproject_name}!")

    _c4_get_subproject_property(${subproject_name} AVAILABLE _available)
    if(_available)
        c4_dbg("required subproject ${subproject_name} was already imported:")
        c4_dbg_subproject(${subproject_name})
    else() #elseif(NOT _${subproject_name}_available)
        c4_dbg("required subproject ${subproject_name} is unknown. Importing...")
        if(_INTERFACE)
            c4_dbg("${subproject_name} is explicitly required as INTERFACE")
            c4_set_var_tmp(C4_LIBRARY_TYPE INTERFACE)
        #elseif(${_c4_uprefix}STANDALONE)
            #c4_dbg("using ${_c4_uprefix}STANDALONE, so import ${subproject_name} as INTERFACE")
            #c4_set_var_tmp(C4_LIBRARY_TYPE INTERFACE)
        endif()
        set(_r ${CMAKE_CURRENT_BINARY_DIR}/subprojects/${subproject_name}) # root
        if(_REMOTE)
            list(FILTER ARGN EXCLUDE REGEX REMOTE)  # remove REMOTE from ARGN
            _c4_mark_subproject_imported(${_c4_lcprefix} ${subproject_name} ${_r}/src ${_r}/build)
            c4_log("importing subproject ${subproject_name} (REMOTE)... ${ARGN}")
            c4_import_remote_proj(${subproject_name} ${_r} ${ARGN})
            c4_dbg("finished importing subproject ${subproject_name} (REMOTE=${${_c4_uprefix}${subproject_name}_SRC_DIR}).")
        elseif(_SUBDIRECTORY)
            list(FILTER ARGN EXCLUDE REGEX SUBDIRECTORY)  # remove SUBDIRECTORY from ARGN
            _c4_mark_subproject_imported(${_c4_lcprefix} ${subproject_name} ${_SUBDIRECTORY} ${_r}/build)
            c4_log("importing subproject ${subproject_name} (SUBDIRECTORY)... ${_SUBDIRECTORY}")
            c4_add_subproj(${subproject_name} ${_SUBDIRECTORY} ${_r}/build)
            c4_dbg("finished importing subproject ${subproject_name} (SUBDIRECTORY=${${_c4_uprefix}${subproject_name}_SRC_DIR}).")
        else()
            message(FATAL_ERROR "subproject type must be either REMOTE or SUBDIRECTORY")
        endif()
        if(_INTERFACE)# OR ${_c4_uprefix}STANDALONE)
            c4_clean_var_tmp(C4_LIBRARY_TYPE)
        endif()
    endif()
endfunction(c4_require_subproject)


function(c4_add_subproj proj dir bindir)
    if("${_c4_curr_subproject}" STREQUAL "")
        set(_c4_curr_subproject ${_c4_prefix})
        set(_c4_curr_path ${_c4_prefix})
    endif()
    set(prev_subproject ${_c4_curr_subproject})
    set(prev_path ${_c4_curr_path})
    set(_c4_curr_subproject ${proj})
    set(_c4_curr_path ${_c4_curr_path}/${proj})
    c4_dbg("adding subproj: ${prev_subproject}->${_c4_curr_subproject}. path=${_c4_curr_path}")
    add_subdirectory(${dir} ${bindir})
    set(_c4_curr_subproject ${prev_subproject})
    set(_c4_curr_path ${prev_path})
endfunction()


function(_c4_mark_subproject_imported importer_subproject subproject_name subproject_src_dir subproject_bin_dir)
    c4_dbg("marking subproject imported: ${subproject_name} (imported by ${importer_subproject}). src=${subproject_src_dir}")
    #
    _c4_get_subproject_property(${importer_subproject} DEPENDENCIES deps)
    if(deps)
        list(APPEND deps ${subproject_name})
    else()
        set(deps ${subproject_name})
    endif()
    _c4_set_subproject_property(${importer_subproject} DEPENDENCIES "${deps}")
    _c4_get_folder(folder ${importer_subproject} ${subproject_name})
    #
    _c4_set_subproject_property(${subproject_name} AVAILABLE ON)
    _c4_set_subproject_property(${subproject_name} IMPORTER "${importer_subproject}")
    _c4_set_subproject_property(${subproject_name} SRC_DIR "${subproject_src_dir}")
    _c4_set_subproject_property(${subproject_name} BIN_DIR "${subproject_bin_dir}")
    _c4_set_subproject_property(${subproject_name} FOLDER "${folder}")
endfunction()


function(_c4_set_subproject_property subproject property value)
    set_property(GLOBAL PROPERTY _c4_subproject-${subproject}-${property} ${value})
endfunction()


function(_c4_get_subproject_property subproject property value)
    get_property(v GLOBAL PROPERTY _c4_subproject-${subproject}-${property})
    set(${value} ${v} PARENT_SCOPE)
endfunction()


function(c4_dbg_subproject subproject)
    set(props AVAILABLE IMPORTER SRC_DIR BIN_DIR DEPENDENCIES FOLDER)
    foreach(p ${props})
        _c4_get_subproject_property(${subproject} ${p} pv)
        c4_dbg("${subproject}: ${p}=${pv}")
    endforeach()
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# download external libs while running cmake:
# https://crascit.com/2015/07/25/cmake-gtest/
# (via https://stackoverflow.com/questions/15175318/cmake-how-to-build-external-projects-and-include-their-targets)
#
# to specify url, repo, tag, or branch,
# pass the needed arguments after dir.
# These arguments will be forwarded to ExternalProject_Add()
function(c4_import_remote_proj name dir)
    set(srcdir_in_out "${dir}")
    c4_download_remote_proj(${name} srcdir_in_out ${ARGN})
    c4_add_subproj(${name} "${srcdir_in_out}" "${dir}/build")
endfunction()


function(c4_set_folder_remote_project_targets subfolder)
    foreach(target ${ARGN})
        set_target_properties(${target} PROPERTIES FOLDER ${_c4_curr_path}/${subfolder})
    endforeach()
endfunction()


function(c4_download_remote_proj name candidate_dir)
    set(dir ${${candidate_dir}})
    set(cvar _${_c4_uprefix}_DOWNLOAD_${name}_LOCATION)
    set(cval ${${cvar}})
    #
    # was it already downloaded in this project?
    if(NOT ("${cval}" STREQUAL ""))
        c4_log("${name} was previously imported into this project: \"${_${_c4_uprefix}_DOWNLOAD_${name}_LOCATION}\"!")
        set(${candidate_dir} "${cval}" PARENT_SCOPE)
        return()
    endif()
    #
    # try to find an existing version (downloaded by some other project)
    set(out "${dir}")
    _c4_find_cached_proj(${name} out)
    if(NOT ("${out}" STREQUAL "${dir}"))
        c4_log("using ${name} from \"${out}\"...")
        set(${cvar} "${out}" CACHE INTERNAL "")
        set(${candidate_dir} "${out}" PARENT_SCOPE)
        return()
    endif()
    #
    # no version was found; need to download.
    c4_log("downloading ${name}: not in cache...")
    # check for a global place to download into
    set(srcdir)
    _c4_get_cached_srcdir_global_extern(${name} srcdir)
    if("${srcdir}" STREQUAL "")
        # none found; default to the given dir
        set(srcdir "${dir}/src")
    endif()
    #
    # do it
    #if((EXISTS ${dir}/dl) AND (EXISTS ${dir}/dl/CMakeLists.txt))
    #    return()
    #endif()
    c4_log("downloading remote project: ${name} -> \"${srcdir}\" (dir=${dir})...")
    #
    file(WRITE ${dir}/dl/CMakeLists.txt "
cmake_minimum_required(VERSION 2.8.2)
project(${_c4_lcprefix}-download-${name} NONE)

# this project only downloads ${name}
# (ie, no configure, build or install step)
include(ExternalProject)

ExternalProject_Add(${name}-dl
    ${ARGN}
    SOURCE_DIR \"${srcdir}\"
    BINARY_DIR \"${dir}/build\"
    CONFIGURE_COMMAND \"\"
    BUILD_COMMAND \"\"
    INSTALL_COMMAND \"\"
    TEST_COMMAND \"\"
)
")
    execute_process(COMMAND ${CMAKE_COMMAND} -G "${CMAKE_GENERATOR}" .
        WORKING_DIRECTORY ${dir}/dl)
    execute_process(COMMAND ${CMAKE_COMMAND} --build .
        WORKING_DIRECTORY ${dir}/dl)
    #
    set(${candidate_dir} "${srcdir}" PARENT_SCOPE)
    set(_${_c4_uprefix}_DOWNLOAD_${name}_LOCATION "${srcdir}" CACHE INTERNAL "")
endfunction()


# checks if the project was already downloaded. If it was, then dir_in_out is
# changed to the directory where the project was found at.
function(_c4_find_cached_proj name dir_in_out)
    c4_log("downloading ${name}: searching cached project...")
    #
    # 1. search in the per-import variable, eg RYML_CACHE_DOWNLOAD_GTEST
    string(TOUPPER ${name} uname)
    set(var ${_c4_uprefix}CACHE_DOWNLOAD_${uname})
    set(val "${${var}}")
    if(NOT ("${val}" STREQUAL ""))
        c4_log("downloading ${name}: searching in ${var}=${val}")
        if(EXISTS "${val}")
            c4_log("downloading ${name}: picked ${sav} instead of ${${dir_in_out}}")
            set(${dir_in_out} ${sav} PARENT_SCOPE)
        endif()
    endif()
    #
    # 2. search in the global directory (if there is one)
    _c4_get_cached_srcdir_global_extern(${name} sav)
    if(NOT ("${sav}" STREQUAL ""))
        c4_log("downloading ${name}: searching in C4_EXTERN_DIR: ${sav}")
        if(EXISTS "${sav}")
            c4_log("downloading ${name}: picked ${sav} instead of ${${dir_in_out}}")
            set(${dir_in_out} ${sav} PARENT_SCOPE)
        endif()
    endif()
endfunction()


function(_c4_get_cached_srcdir_global_extern name out)
    set(${out} "" PARENT_SCOPE)
    if("${C4_EXTERN_DIR}" STREQUAL "")
        set(C4_EXTERN_DIR "$ENV{C4PROJ_EXTERN_DIR}")
    endif()
    if(NOT ("${C4_EXTERN_DIR}" STREQUAL ""))
        set(${out} "${C4_EXTERN_DIR}/${name}" PARENT_SCOPE)
    endif()
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

function(_c4_get_folder output importer_subproject subproject_name)
    _c4_get_subproject_property(${importer_subproject} FOLDER importer_folder)
    if("${importer_folder}" STREQUAL "")
        set(folder ${importer_subproject})
    else()
        set(folder "${importer_folder}/deps/${subproject_name}")
    endif()
    set(${output} ${folder} PARENT_SCOPE)
endfunction()


function(_c4_set_target_folder target name_to_append)
    if("${name_to_append}" STREQUAL "")
        set_target_properties(${name} PROPERTIES FOLDER "${_c4_curr_path}")
    else()
        if("${_c4_curr_path}" STREQUAL "")
            set_target_properties(${target} PROPERTIES FOLDER ${name_to_append})
        else()
            set_target_properties(${target} PROPERTIES FOLDER ${_c4_curr_path}/${name_to_append})
        endif()
    endif()
endfunction()


function(c4_set_folder_remote_project_targets subfolder)
    foreach(target ${ARGN})
        if(TARGET ${target})
            _c4_set_target_folder(${target} "${subfolder}")
        endif()
    endforeach()
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# a convenience alias to c4_add_target()
function(c4_add_executable name)
    c4_add_target(${name} EXECUTABLE ${ARGN})
endfunction(c4_add_executable)


# a convenience alias to c4_add_target()
function(c4_add_library name)
    c4_add_target(${name} LIBRARY ${ARGN})
endfunction(c4_add_library)


# example: c4_add_target(ryml LIBRARY SOURCES ${SRC})
function(c4_add_target name)
    c4_dbg("adding target: ${name}: ${ARGN}")
    set(opt0arg
        LIBRARY     # the target is a library
        EXECUTABLE  # the target is an executable
        WIN32       # the executable is WIN32
        SANITIZE    # turn on sanitizer analysis
    )
    set(opt1arg
        LIBRARY_TYPE    # override global setting for C4_LIBRARY_TYPE
        SOURCE_ROOT     # the directory where relative source paths
                        # should be resolved. when empty,
                        # use CMAKE_CURRENT_SOURCE_DIR
        FOLDER          # IDE folder to group the target in
        SANITIZERS      # outputs the list of sanitize targets in this var
        SOURCE_TRANSFORM
    )
    set(optnarg
        INCORPORATE  # incorporate these libraries into this target,
                     # subject to ${_c4_uprefix}STANDALONE and C4_STANDALONE
        SOURCES  PUBLIC_SOURCES  INTERFACE_SOURCES  PRIVATE_SOURCES
        HEADERS  PUBLIC_HEADERS  INTERFACE_HEADERS  PRIVATE_HEADERS
        INC_DIRS PUBLIC_INC_DIRS INTERFACE_INC_DIRS PRIVATE_INC_DIRS
        LIBS     PUBLIC_LIBS     INTERFACE_LIBS     PRIVATE_LIBS
        DLLS           # DLLs required by this target
        MORE_ARGS
    )
    cmake_parse_arguments("" "${opt0arg}" "${opt1arg}" "${optnarg}" ${ARGN})

    if(${_LIBRARY})
        set(_what LIBRARY)
    elseif(${_EXECUTABLE})
        set(_what EXECUTABLE)
    else()
        message(FATAL_ERROR "must be either LIBRARY or EXECUTABLE")
    endif()

    _c4_handle_arg_or_fallback(SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
    function(c4_transform_to_full_path list all)
        set(l)
        foreach(f ${${list}})
            if(NOT IS_ABSOLUTE "${f}")
                set(f "${_SOURCE_ROOT}/${f}")
            endif()
            list(APPEND l "${f}")
        endforeach()
        set(${list} "${l}" PARENT_SCOPE)
        set(cp ${${all}})
        list(APPEND cp ${l})
        set(${all} ${cp} PARENT_SCOPE)
    endfunction()
    c4_transform_to_full_path(          _SOURCES allsrc)
    c4_transform_to_full_path(          _HEADERS allsrc)
    c4_transform_to_full_path(   _PUBLIC_SOURCES allsrc)
    c4_transform_to_full_path(_INTERFACE_SOURCES allsrc)
    c4_transform_to_full_path(  _PRIVATE_SOURCES allsrc)
    c4_transform_to_full_path(   _PUBLIC_HEADERS allsrc)
    c4_transform_to_full_path(_INTERFACE_HEADERS allsrc)
    c4_transform_to_full_path(  _PRIVATE_HEADERS allsrc)

    create_source_group("" "${CMAKE_CURRENT_SOURCE_DIR}" "${allsrc}")

    if(NOT ${_c4_uprefix}SANITIZE_ONLY)
        if(${_EXECUTABLE})
            c4_dbg("adding executable: ${name}")
            if(WIN32)
                if(${_WIN32})
                    list(APPEND _MORE_ARGS WIN32)
                endif()
            endif()
	    add_executable(${name} ${_MORE_ARGS})
	    set(src_mode PRIVATE)
            set(tgt_type PUBLIC)
            set(compiled_target ON)
        elseif(${_LIBRARY})
            c4_dbg("adding library: ${name}")
            set(_blt ${C4_LIBRARY_TYPE})
            if(NOT "${_LIBRARY_TYPE}" STREQUAL "")
                set(_blt ${_LIBRARY_TYPE})
            endif()
            #
            if("${_blt}" STREQUAL "INTERFACE")
                c4_dbg("adding interface library ${name}")
                add_library(${name} INTERFACE)
                set(src_mode INTERFACE)
                set(tgt_type INTERFACE)
                set(compiled_target OFF)
            else()
                if(NOT ("${_blt}" STREQUAL ""))
                    c4_dbg("adding library ${name} with type ${_blt}")
                    add_library(${name} ${_blt} ${_MORE_ARGS})
                else()
                    # obey BUILD_SHARED_LIBS (ie, either static or shared library)
                    c4_dbg("adding library ${name} (defer to BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}) --- ${_MORE_ARGS}")
                    add_library(${name} ${_MORE_ARGS})
                endif()
                # libraries
                set(src_mode PRIVATE)
                set(tgt_type PUBLIC)
                set(compiled_target ON)
            endif()
        endif(${_EXECUTABLE})

        if(src_mode STREQUAL "PUBLIC")
            c4_add_target_sources(${name}
                PUBLIC    "${_SOURCES};${_HEADERS};${_PUBLIC_SOURCES};${_PUBLIC_HEADERS}"
                INTERFACE "${_INTERFACE_SOURCES};${_INTERFACE_HEADERS}"
                PRIVATE   "${_PRIVATE_SOURCES};${_PRIVATE_HEADERS}")
        elseif(src_mode STREQUAL "INTERFACE")
            c4_add_target_sources(${name}
                PUBLIC    "${_PUBLIC_SOURCES};${_PUBLIC_HEADERS}"
                INTERFACE "${_SOURCES};${_HEADERS};${_INTERFACE_SOURCES};${_INTERFACE_HEADERS}"
                PRIVATE   "${_PRIVATE_SOURCES};${_PRIVATE_HEADERS}")
        elseif(src_mode STREQUAL "PRIVATE")
            c4_add_target_sources(${name}
                PUBLIC    "${_PUBLIC_SOURCES};${_PUBLIC_HEADERS}"
                INTERFACE "${_INTERFACE_SOURCES};${_INTERFACE_HEADERS}"
                PRIVATE   "${_SOURCES};${_HEADERS};${_PRIVATE_SOURCES};${_PRIVATE_HEADERS}")
        elseif()
            message(FATAL_ERROR "${_c4_lcprefix}: adding sources for target ${target} invalid source mode")
        endif()
        set_target_properties(${name} PROPERTIES C4_SOURCE_ROOT "${_SOURCE_ROOT}")

        if(_INC_DIRS)
            c4_dbg("${name}: adding include dirs ${_INC_DIRS} [from target: ${tgt_type}]")
            target_include_directories(${name} "${tgt_type}" ${_INC_DIRS})
        endif()
        if(_PUBLIC_INC_DIRS)
            c4_dbg("${name}: adding PUBLIC include dirs ${_PUBLIC_INC_DIRS}")
            target_include_directories(${name} PUBLIC ${_PUBLIC_INC_DIRS})
        endif()
        if(_INTERFACE_INC_DIRS)
            c4_dbg("${name}: adding INTERFACE include dirs ${_INTERFACE_INC_DIRS}")
            target_include_directories(${name} INTERFACE ${_INTERFACE_INC_DIRS})
        endif()
        if(_PRIVATE_INC_DIRS)
            c4_dbg("${name}: adding PRIVATE include dirs ${_PRIVATE_INC_DIRS}")
            target_include_directories(${name} PRIVATE ${_PRIVATE_INC_DIRS})
        endif()

        if(_LIBS)
            _c4_link_with_libs(${name} "${tgt_type}" "${_LIBS}" "${_INCORPORATE}")
        endif()
        if(_PUBLIC_LIBS)
            _c4_link_with_libs(${name} PUBLIC "${_PUBLIC_LIBS}" "${_INCORPORATE}")
        endif()
        if(_INTERFACE_LIBS)
            _c4_link_with_libs(${name} INTERFACE "${_INTERFACE_LIBS}" "${_INCORPORATE}")
        endif()
        if(_PRIVATE_LIBS)
            _c4_link_with_libs(${name} PRIVATE "${_PRIVATE_LIBS}" "${_INCORPORATE}")
        endif()

        if(compiled_target)
            c4_target_inherit_cxx_standard(${name})
            _c4_set_target_folder(${name} "${_FOLDER}")
            if(${_c4_uprefix}CXX_FLAGS OR ${_c4_uprefix}C_FLAGS OR ${_c4_uprefix}CXX_FLAGS_OPT)
                #print_var(${_c4_uprefix}CXX_FLAGS)
                set_target_properties(${name} PROPERTIES
                    COMPILE_FLAGS ${${_c4_uprefix}CXX_FLAGS} ${${_c4_uprefix}C_FLAGS} ${${_c4_uprefix}CXX_FLAGS_OPT})
            endif()
            if(${_c4_uprefix}LINT)
                c4_static_analysis_target(${name} "${_FOLDER}" lint_targets)
            endif()
        endif(compiled_target)
    endif(NOT ${_c4_uprefix}SANITIZE_ONLY)

    if(compiled_target)
        if(_SANITIZE OR ${_c4_uprefix}SANITIZE)
            c4_sanitize_target(${name}
                ${_what}   # LIBRARY or EXECUTABLE
                SOURCES ${allsrc}
                INC_DIRS ${_INC_DIRS} ${_PUBLIC_INC_DIRS} ${_INTERFACE_INC_DIRS} ${_PRIVATE_INC_DIRS}
                LIBS ${_LIBS} ${_PUBLIC_LIBS} ${_INTERFACE_LIBS} ${_PRIVATE_LIBS}
                OUTPUT_TARGET_NAMES san_targets
                FOLDER "${_FOLDER}"
                )
        endif()

        if(NOT ${_c4_uprefix}SANITIZE_ONLY)
            list(INSERT san_targets 0 ${name})
        endif()

        if(_SANITIZERS)
            set(${_SANITIZERS} ${san_targets} PARENT_SCOPE)
        endif()
    endif()

    # gather dlls so that they can be automatically copied to the target directory
    if(_DLLS)
        c4_set_transitive_property(${name} _C4_DLLS "${_DLLS}")
        get_target_property(vd ${name} _C4_DLLS)
    endif()

    if(${_EXECUTABLE})
        if(WIN32)
            c4_get_transitive_property(${name} _C4_DLLS transitive_dlls)
            foreach(_dll ${transitive_dlls})
                if(_dll)
                    c4_dbg("enable copy of dll to target file dir: ${_dll} ---> $<TARGET_FILE_DIR:${name}>")
                    add_custom_command(TARGET ${name} POST_BUILD
                        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_dll}" $<TARGET_FILE_DIR:${name}>
                        COMMENT "${name}: requires dll: ${_dll} ---> $<TARGET_FILE_DIR:${name}"
                        )
                else()
                    message(WARNING "dll required by ${_c4_prefix}/${name} was not found, so cannot copy: ${_dll}")
                endif()
            endforeach()
        endif()
    endif()
endfunction() # add_target


function(_c4_link_with_libs target link_type libs incorporate)
    foreach(lib ${libs})
        if(incorporate AND (
                    (C4_STANDALONE OR ${_c4_uprefix}STANDALONE)
                    AND
                    (NOT (${lib} IN_LIST incorporate))))
            c4_dbg("-----> ${target} ${link_type} incorporating lib ${lib}")
            _c4_incorporate_lib(${target} ${link_type} ${lib})
        else()
            c4_dbg("${target} ${link_type} linking with lib ${lib}")
            target_link_libraries(${target} ${link_type} ${lib})
        endif()
    endforeach()
endfunction()


function(_c4_incorporate_lib target link_type splib)
    #
    _c4_get_tgt_prop(splib_src ${splib} SOURCES)
    if(splib_src)
        create_source_group("" "${CMAKE_CURRENT_SOURCE_DIR}" "${splib_src}")
        c4_add_target_sources(${target} PRIVATE ${splib_src})
    endif()
    #
    _c4_get_tgt_prop(splib_isrc ${splib} INTERFACE_SOURCES)
    if(splib_isrc)
        c4_add_target_sources(${target} INTERFACE ${splib_isrc})
    endif()
    #
    #
    _c4_get_tgt_prop(splib_incs ${splib} INCLUDE_DIRECTORIES)
    if(splib_incs)
        target_include_directories(${target} PUBLIC ${splib_incs})
    endif()
    #
    _c4_get_tgt_prop(splib_iincs ${splib} INTERFACE_INCLUDE_DIRECTORIES)
    if(splib_iincs)
        target_include_directories(${target} INTERFACE ${splib_iincs})
    endif()
    #
    #
    _c4_get_tgt_prop(splib_lib ${splib} LINK_LIBRARIES)
    if(splib_lib)
        target_link_libraries(${target} PUBLIC ${splib_lib})
    endif()
    _c4_get_tgt_prop(splib_ilib ${splib} INTERFACE_LIBRARY)
    if(splib_ilib)
        target_link_libraries(${target} INTERFACE ${splib_ilib})
    endif()
endfunction()


function(_c4_get_tgt_prop out tgt prop)
    get_target_property(val ${tgt} ${prop})
    c4_dbg("${tgt}: ${prop}=${val}")
    set(${out} ${val} PARENT_SCOPE)
endfunction()


# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# WIP, under construction (still incomplete)
# see: https://github.com/pr0g/cmake-examples
# see: https://cliutils.gitlab.io/modern-cmake/


function(c4_install_target target)
    # zero-value macro arguments
    set(opt0arg
    )
    # one-value macro arguments
    set(opt1arg
        EXPORT # the name of the export target. default: see below.
    )
    # multi-value macro arguments
    set(optNarg
    )
    cmake_parse_arguments("" "${opt0arg}" "${opt1arg}" "${optNarg}" ${ARGN})
    #
    _c4_handle_arg(EXPORT "${_c4_prefix}-export")
    #
    _c4_setup_install_vars()
    # TODO: don't forget to install DLLs: _${_c4_uprefix}_${target}_DLLS
    install(TARGETS ${target}
        EXPORT ${_EXPORT}
        RUNTIME DESTINATION ${_RUNTIME_INSTALL_DIR}
        ARCHIVE DESTINATION ${_ARCHIVE_INSTALL_DIR}
        LIBRARY DESTINATION ${_LIBRARY_INSTALL_DIR}
        OBJECTS DESTINATION ${_OBJECTS_INSTALL_DIR}
        INCLUDES DESTINATION ${_INCLUDE_INSTALL_DIR}
        )
    #
    c4_install_sources(${target} include)
    #
    set(l ${${_c4_prefix}_TARGETS})
    list(APPEND l ${target})
    set(${_c4_prefix}_TARGETS ${l} PARENT_SCOPE)
    #
#    # pkgconfig (WIP)
#    set(pc ${CMAKE_CURRENT_BINARY_DIR}/pkgconfig/${target}.pc)
#    file(WRITE ${pc} "# pkg-config: ${target}
#
#prefix=\"${CMAKE_INSTALL_PREFIX}\"
#exec_prefix=\"\${_c4_prefix}\"
#libdir=\"\${_c4_prefix}/${CMAKE_INSTALL_LIBDIR}\"
#includedir=\"\${_c4_prefix}/include\"
#
#Name: ${target}
#Description: A library for xyzzying frobnixes
#URL: https://github.com/me/mylibrary
#Version: 0.0.0
#Requires: @PKGCONF_REQ_PUB@
#Requires.private: @PKGCONF_REQ_PRIV@
#Cflags: -I\"${includedir}\"
#Libs: -L\"${libdir}\" -lmylibrary
#Libs.private: -L\"${libdir}\" -lmylibrary @PKGCONF_LIBS_PRIV@
#")
#    _c4_setup_install_vars()
#    install(FILES ${pc} DESTINATION "${_ARCHIVE_INSTALL_DIR}/pkgconfig/")
endfunction()


function(c4_install_exports)
    # zero-value macro arguments
    set(opt0arg
    )
    # one-value macro arguments
    set(opt1arg
        PREFIX     # override the c4 project-wide prefix. This will be used in the cmake
        TARGET     # the name of the exports target
        NAMESPACE  # the namespace for the targets
    )
    # multi-value macro arguments
    set(optNarg
        DEPENDENCIES
    )
    cmake_parse_arguments("" "${opt0arg}" "${opt1arg}" "${optNarg}" ${ARGN})
    #
    _c4_handle_arg(PREFIX    "${_c4_prefix}")
    _c4_handle_arg(TARGET    "${_c4_prefix}-export")
    _c4_handle_arg(NAMESPACE "${_c4_prefix}::")
    #
    _c4_setup_install_vars()
    #
    list(GET ${_c4_prefix}_TARGETS 0 target)
    set(exported_target "${_NAMESPACE}${target}")
    set(targets_file "${_PREFIX}Targets.cmake")
    #
    set(deps)
    if(_DEPENDENCIES)
        set(deps "#-----------------------------
include(CMakeFindDependencyMacro)")
        foreach(d ${_DEPENDENCIES})
            set(deps "${deps}
find_dependency(${d} REQUIRED)
")
        endforeach()
        set(deps "${deps}
#-----------------------------")
    endif()
    #
    # cfg_dst is the path relative to install root where the export
    # should be installed; cfg_dst_rel is the path from there to
    # the install root
    macro(__c4_install_exports cfg_dst cfg_dst_rel)
        # make sure that different exports are staged in different directories
        set(case export_cases/${cfg_dst})
        file(MAKE_DIRECTORY ${case})
        #
        install(EXPORT "${_TARGET}"
            FILE "${targets_file}"
            NAMESPACE "${_NAMESPACE}"
            DESTINATION "${cfg_dst}")
        #
        # Config files
        # the module below has nice docs in it; do read them
        # to understand the macro calls below
        include(CMakePackageConfigHelpers)
        set(cfg ${CMAKE_CURRENT_BINARY_DIR}/${case}/${_PREFIX}Config.cmake)
        set(cfg_ver ${CMAKE_CURRENT_BINARY_DIR}/${case}/${_PREFIX}ConfigVersion.cmake)
        #
        file(WRITE ${cfg}.in "${deps}
set(${_c4_uprefix}VERSION ${${_c4_uprefix}VERSION})

@PACKAGE_INIT@

if(NOT TARGET ${exported_target})
    include(\${PACKAGE_PREFIX_DIR}/${targets_file})
endif()

# HACK: PACKAGE_PREFIX_DIR is obtained from the PACKAGE_INIT macro above;
# When used below in the calls to set_and_check(),
# it points at the location of this file. So point it instead
# to the CMAKE_INSTALL_PREFIX, in relative terms
get_filename_component(PACKAGE_PREFIX_DIR
    \"\${PACKAGE_PREFIX_DIR}/${cfg_dst_rel}\" ABSOLUTE)

set_and_check(${_c4_uprefix}INCLUDE_DIR \"@PACKAGE__INCLUDE_INSTALL_DIR@\")
set_and_check(${_c4_uprefix}LIB_DIR \"@PACKAGE__LIBRARY_INSTALL_DIR@\")
#set_and_check(${_c4_uprefix}SYSCONFIG_DIR \"@PACKAGE__SYSCONFIG_INSTALL_DIR@\")

check_required_components(${_c4_lcprefix})
")
        configure_package_config_file(${cfg}.in ${cfg}
            INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}"  # defaults to CMAKE_INSTALL_PREFIX
            INSTALL_DESTINATION "${CMAKE_INSTALL_PREFIX}"
            PATH_VARS
                _INCLUDE_INSTALL_DIR
                _LIBRARY_INSTALL_DIR
                _SYSCONFIG_INSTALL_DIR
            #NO_SET_AND_CHECK_MACRO
            #NO_CHECK_REQUIRED_COMPONENTS_MACRO
        )
        write_basic_package_version_file(
            ${cfg_ver}
            VERSION ${${_c4_uprefix}VERSION}
            COMPATIBILITY AnyNewerVersion
        )
        install(FILES ${cfg} ${cfg_ver} DESTINATION ${cfg_dst})
    endmacro(__c4_install_exports)
    #
    # To install the exports:
    #
    # Windows:
    # <prefix>/
    # <prefix>/(cmake|CMake)/
    # <prefix>/<name>*/
    # <prefix>/<name>*/(cmake|CMake)/
    #
    # Unix:
    # <prefix>/(lib/<arch>|lib|share)/cmake/<name>*/
    # <prefix>/(lib/<arch>|lib|share)/<name>*/
    # <prefix>/(lib/<arch>|lib|share)/<name>*/(cmake|CMake)/
    #
    # Apple:
    # <prefix>/<name>.framework/Resources/
    # <prefix>/<name>.framework/Resources/CMake/
    # <prefix>/<name>.framework/Versions/*/Resources/
    # <prefix>/<name>.framework/Versions/*/Resources/CMake/
    # <prefix>/<name>.app/Contents/Resources/
    # <prefix>/<name>.app/Contents/Resources/CMake/
    #
    # (This was taken from the find_package() documentation)
    if(WIN32)
        __c4_install_exports(cmake/ "..")
    elseif(APPLE)
        message(FATAL_ERROR "not implemented")
    elseif(UNIX)
        __c4_install_exports(${_ARCHIVE_INSTALL_DIR}/cmake/${_c4_prefix} "../../..")
    else()
        message(FATAL_ERROR "unknown platform")
    endif()
endfunction()


macro(_c4_setup_install_vars)
    set(_RUNTIME_INSTALL_DIR   bin/)
    set(_ARCHIVE_INSTALL_DIR   lib/)
    set(_LIBRARY_INSTALL_DIR   lib/) # TODO on Windows, ARCHIVE and LIBRARY dirs must be different to prevent name clashes
    set(_INCLUDE_INSTALL_DIR   include/)
    set(_OBJECTS_INSTALL_DIR   obj/)
    set(_SYSCONFIG_INSTALL_DIR etc/${_c4_lcprefix}/)
endmacro()


function(c4_install_files files destination relative_to)
    c4_dbg("adding files to install list, destination ${destination}: ${files}")
    foreach(f ${files})
        file(RELATIVE_PATH rf "${relative_to}" ${f})
        get_filename_component(rd "${rf}" DIRECTORY)
        install(FILES ${f} DESTINATION "${destination}/${rd}" ${ARGN})
    endforeach()
endfunction()


function(c4_install_directories directories destination relative_to)
    c4_dbg("adding directories to install list, destination ${destination}: ${directories}")
    foreach(d ${directories})
        file(RELATIVE_PATH rf "${relative_to}" ${d})
        get_filename_component(rd "${rf}" DIRECTORY)
        install(DIRECTORY ${d} DESTINATION "${destination}/${rd}" ${ARGN})
    endforeach()
endfunction()


function(c4_install_sources target destination)
    # executables have no sources requiring install
    get_target_property(target_type ${target} TYPE)
    if(target_type STREQUAL "EXECUTABLE")
        return() # nothing to do
    endif()
    # get the sources from the target
    _c4_get_tgt_prop(src ${target} SOURCES)
    _c4_get_tgt_prop(isrc ${target} INTERFACE_SOURCES)
    _c4_get_tgt_prop(srcroot ${target} C4_SOURCE_ROOT)
    if(src)
        _c4cat_filter_hdrs("${src}" hdr)
        c4_install_files("${hdr}" "${destination}" "${srcroot}")
    endif()
    if(isrc)
        _c4cat_filter_srcs_hdrs("${isrc}" isrc)
        c4_install_files("${isrc}" "${destination}" "${srcroot}")
    endif()
endfunction()


function(c4_get_target_installed_headers target out)
    set(hdrs)
    _c4_get_tgt_prop(src ${target} SOURCES)
    _c4_get_tgt_prop(isrc ${target} INTERFACE_SOURCES)
    _c4_get_tgt_prop(srcroot ${target} C4_SOURCE_ROOT)
    if(src)
        _c4cat_filter_hdrs("${src}" h_)
        foreach(h ${h_})
            file(RELATIVE_PATH rf "${srcroot}" "${h}")
            list(APPEND hdrs "${rf}")
        endforeach()
    endif()
    if(isrc)
        _c4cat_filter_hdrs("${isrc}" h_)
        foreach(h ${h_})
            file(RELATIVE_PATH rf "${srcroot}" "${h}")
            list(APPEND hdrs "${rf}")
        endforeach()
    endif()
    set(${out} ${hdrs} PARENT_SCOPE)
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
function(c4_setup_testing)
    #include(GoogleTest) # this module requires at least cmake 3.9
    c4_dbg("enabling tests")
    # umbrella target for building test binaries
    add_custom_target(${_c4_lprefix}test-build)
    set_target_properties(${_c4_lprefix}test-build PROPERTIES FOLDER ${_c4_curr_path}/${_c4_lprefix}test)
    _c4_set_target_folder(${_c4_lprefix}test-build ${_c4_lprefix}test)
    # umbrella target for running tests
    set(ctest_cmd env CTEST_OUTPUT_ON_FAILURE=1 ${CMAKE_CTEST_COMMAND} ${${_c4_uprefix}CTEST_OPTIONS} -C $<CONFIG>)
    add_custom_target(${_c4_lprefix}test
        ${CMAKE_COMMAND} -E echo CWD=${CMAKE_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E echo
        COMMAND ${CMAKE_COMMAND} -E echo ----------------------------------
        COMMAND ${CMAKE_COMMAND} -E echo ${ctest_cmd}
        COMMAND ${CMAKE_COMMAND} -E echo ----------------------------------
        COMMAND ${CMAKE_COMMAND} -E ${ctest_cmd}
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        DEPENDS ${_c4_lprefix}test-build
        )
    _c4_set_target_folder(${_c4_lprefix}test ${_c4_lprefix}test)

    #if(MSVC)
    #    # silence MSVC pedantic error on googletest's use of tr1: https://github.com/google/googletest/issues/1111
    #    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /D_SILENCE_TR1_NAMESPACE_DEPRECATION_WARNING")
    #endif()
    c4_override(BUILD_GTEST ON)
    c4_override(BUILD_GMOCK OFF)
    c4_override(gtest_force_shared_crt ON)
    c4_override(gtest_build_samples OFF)
    c4_override(gtest_build_tests OFF)
    c4_import_remote_proj(gtest ${CMAKE_CURRENT_BINARY_DIR}/extern/gtest
        GIT_REPOSITORY https://github.com/google/googletest.git
        #GIT_TAG release-1.8.0
        )
    c4_set_folder_remote_project_targets(${_c4_lprefix}test gtest gtest_main)
endfunction(c4_setup_testing)


function(c4_add_test target)
    #
    if(NOT ${uprefix}SANITIZE_ONLY)
        add_test(NAME ${target}-run COMMAND $<TARGET_FILE:${target}>)
    endif()
    #
    if("${CMAKE_BUILD_TYPE}" STREQUAL "Coverage")
        add_dependencies(${_c4_lprefix}test-build ${target})
        return()
    endif()
    #
    set(sanitized_targets)
    foreach(s asan msan tsan ubsan)
        set(t ${target}-${s})
        if(TARGET ${t})
            list(APPEND sanitized_targets ${s})
        endif()
    endforeach()
    if(sanitized_targets)
        add_custom_target(${target}-all)
        add_dependencies(${target}-all ${target})
        add_dependencies(${_c4_lprefix}test-build ${target}-all)
        _c4_set_target_folder(${target}-all ${_c4_lprefix}test/${target})
    else()
        add_dependencies(${_c4_lprefix}test-build ${target})
    endif()
    if(sanitized_targets)
        foreach(s asan msan tsan ubsan)
            set(t ${target}-${s})
            if(TARGET ${t})
                add_dependencies(${target}-all ${t})
                c4_sanitize_get_target_command($<TARGET_FILE:${t}> ${s} cmd)
                #message(STATUS "adding test: ${t}-run")
                add_test(NAME ${t}-run COMMAND ${cmd})
            endif()
        endforeach()
    endif()
    if(NOT ${_c4_uprefix}SANITIZE_ONLY)
        c4_add_valgrind(${target})
    endif()
    if(${_c4_uprefix}LINT)
        c4_static_analysis_add_tests(${target})
    endif()
endfunction(c4_add_test)


# every excess argument is passed on to set_target_properties()
function(c4_add_test_fail_build name srccontent_or_srcfilename)
    #
    set(sdir ${CMAKE_CURRENT_BINARY_DIR}/test_fail_build)
    set(src ${srccontent_or_srcfilename})
    if("${src}" STREQUAL "")
        message(FATAL_ERROR "must be given an existing source file name or a non-empty string")
    endif()
    #
    if(EXISTS ${src})
        set(fn ${src})
    else()
        if(NOT EXISTS ${sdir})
            file(MAKE_DIRECTORY ${sdir})
        endif()
        set(fn ${sdir}/${name}.cpp)
        file(WRITE ${fn} "${src}")
    endif()
    #
    # https://stackoverflow.com/questions/30155619/expected-build-failure-tests-in-cmake
    add_executable(${name} ${fn})
    # don't build this target
    set_target_properties(${name} PROPERTIES
        EXCLUDE_FROM_ALL TRUE
        EXCLUDE_FROM_DEFAULT_BUILD TRUE
        # and pass on further properties given by the caller
        ${ARGN})
    add_test(NAME ${name}
        COMMAND ${CMAKE_COMMAND} --build . --target ${name} --config $<CONFIGURATION>
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
    set_tests_properties(${name} PROPERTIES WILL_FAIL TRUE)
endfunction()


function(c4_add_install_link_test library namespace exe_source_code)
    _c4_add_library_client_test(${library} "${namespace}" "${_c4_lprefix}test-${library}-install-link" "${exe_source_code}")
endfunction()


function(c4_add_install_include_test library namespace)
    c4_get_target_installed_headers(${library} incfiles)
    set(incblock)
    foreach(i ${incfiles})
        set(incblock "${incblock}
#include <${i}>")
    endforeach()
    set(src "${incblock}

int main()
{
    return 0;
}
")
    _c4_add_library_client_test(${library} "${namespace}" "${_c4_lprefix}test-${library}-install-include" "${src}")
endfunction()


function(_c4_add_library_client_test library namespace pname source_code)
    if("${CMAKE_BUILD_TYPE}" STREQUAL Coverage)
        add_test(NAME ${pname}-run
            COMMAND ${CMAKE_COMMAND} -E echo "skipping this test in coverage builds"
            )
        return()
    endif()
    set(pdir "${CMAKE_CURRENT_BINARY_DIR}/${pname}")
    set(bdir "${pdir}/build")
    if(NOT EXISTS "${pdir}")
        file(MAKE_DIRECTORY "${pdir}")
    endif()
    if(NOT EXISTS "${bdir}/build")
        file(MAKE_DIRECTORY "${bdir}/build")
    endif()
    set(psrc "${pdir}/${pname}.cpp")
    set(tsrc "${pdir}/${pname}-run.cmake")
    set(tout "${pdir}/${pname}-run-out.log")
    # generate the source file
    file(WRITE "${psrc}" "${source_code}")
    # generate the cmake project consuming this library
    file(WRITE "${pdir}/CMakeLists.txt" "
cmake_minimum_required(VERSION 3.12)
project(${pname} LANGUAGES CXX)

find_package(${library} REQUIRED)

message(STATUS \"
found ${library}:
    ${_c4_uprefix}INCLUDE_DIR=\${${_c4_uprefix}INCLUDE_DIR}
    ${_c4_uprefix}LIB_DIR=\${${_c4_uprefix}LIB_DIR}
\")

add_executable(${pname} ${pname}.cpp)
# this must be the only required setup to link with ${library}
target_link_libraries(${pname} PUBLIC ${namespace}${library})

add_custom_target(${pname}-run
    COMMAND \$<TARGET_FILE:${pname}>
    DEPENDS ${pname}
)
")
    # The test consists in running the script generated below.
    # We force evaluation of the configuration generator expression
    # by receiving its result via the command line.
    add_test(NAME ${pname}-run
        COMMAND ${CMAKE_COMMAND} -DCFG_IN=$<CONFIG> -P "${tsrc}"
        )
    # NOTE: in the cmake configure command, be sure to NOT use quotes
    # in -DCMAKE_PREFIX_PATH=\"${CMAKE_INSTALL_PREFIX}\". Use
    # -DCMAKE_PREFIX_PATH=${CMAKE_INSTALL_PREFIX} instead.
    # So here we add a check to make sure the install path has no spaces
    string(FIND "${CMAKE_INSTALL_PREFIX}" " " has_spaces)
    if(NOT (has_spaces EQUAL -1))
        message(FATAL_ERROR "install tests will fail if the install path has spaces: '${CMAKE_INSTALL_PREFIX}' : ... ${has_spaces}")
    endif()
    # make sure the test project uses the same architecture
    # CMAKE_VS_PLATFORM_NAME is available only since cmake 3.9
    # see https://cmake.org/cmake/help/v3.9/variable/CMAKE_GENERATOR_PLATFORM.html
    if(WIN32)
        set(cfg_opt "--config \${cfg}")
        if(CMAKE_GENERATOR_PLATFORM OR CMAKE_VS_PLATFORM_NAME)
            set(arch "-DCMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}" "-DCMAKE_VS_PLATFORM_NAME=${CMAKE_VS_PLATFORM_NAME}")
        else()
            if(CMAKE_SIZEOF_VOID_P EQUAL 8)
                set(arch -A x64)
            elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
                set(arch -A Win32)
            else()
                message(FATAL_ERROR "not implemented")
            endif()
        endif()
    elseif(ANDROID OR IOS OR WINCE OR WINDOWS_PHONE)
        message(FATAL_ERROR "not implemented")
    elseif(IOS)
        message(FATAL_ERROR "not implemented")
    elseif(UNIX)
        if(CMAKE_GENERATOR_PLATFORM OR CMAKE_VS_PLATFORM_NAME)
            set(arch "-DCMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}" "-DCMAKE_VS_PLATFORM_NAME=${CMAKE_VS_PLATFORM_NAME}")
        else()
            if(CMAKE_SIZEOF_VOID_P EQUAL 8)
                set(arch "-DCMAKE_CXX_FLAGS=-m64")
            elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
                set(arch "-DCMAKE_CXX_FLAGS=-m32")
            else()
                message(FATAL_ERROR "not implemented")
            endif()
        endif()
    endif()
    # generate the cmake script with the test content
    file(WRITE "${tsrc}" "
# run a command and check its return status
function(runcmd)
    message(STATUS \"Running command: \${ARGN}\")
    message(STATUS \"Running command: output goes to ${tout}\")
    execute_process(
        COMMAND \${ARGN}
        RESULT_VARIABLE retval
        OUTPUT_FILE \"${tout}\"
        ERROR_FILE \"${tout}\"
        # COMMAND_ECHO STDOUT  # only available from cmake-3.15
    )
    file(READ \"${tout}\" output)
    message(STATUS \"output:
--------------------
\${output}--------------------\")
    message(STATUS \"Exit status was \${retval}: \${ARGN}\")
    if(NOT (\${retval} EQUAL 0))
        message(FATAL_ERROR \"Command failed with exit status \${retval}: \${ARGN}\")
    endif()
endfunction()

set(cmk \"${CMAKE_COMMAND}\")
set(pfx \"${CMAKE_INSTALL_PREFIX}\")
set(idir \"${CMAKE_BINARY_DIR}\")
set(pdir \"${pdir}\")
set(bdir \"${bdir}\")

# force evaluation of the configuration generator expression
# by receiving its result via the command line
set(cfg \${CFG_IN})

# install the library
#runcmd(\"\${cmk}\" --install \"\${idir}\" ${cfg_opt})  # requires cmake>3.13 (at least)
runcmd(\"\${cmk}\" --build \"\${idir}\" ${cfg_opt} --target install)

# configure the client project
runcmd(\"\${cmk}\" -S \"\${pdir}\" -B \"\${bdir}\" \"-DCMAKE_PREFIX_PATH=\${pfx}\" \"-DCMAKE_GENERATOR=${CMAKE_GENERATOR}\" ${arch} \"-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}\" \"-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}\")

# build the client project
runcmd(\"\${cmk}\" --build \"\${bdir}\" ${cfg_opt})

# run the client executable
runcmd(\"\${cmk}\" --build \"\${bdir}\" --target \"${pname}-run\" ${cfg_opt})
")
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
function(c4_setup_valgrind umbrella_option)
    if(UNIX AND (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Coverage"))
        cmake_dependent_option(${_c4_uprefix}VALGRIND "enable valgrind tests" ON ${umbrella_option} OFF)
        cmake_dependent_option(${_c4_uprefix}VALGRIND_SGCHECK "enable valgrind tests with the exp-sgcheck tool" OFF ${umbrella_option} OFF)
        set(${_c4_uprefix}VALGRIND_OPTIONS "--gen-suppressions=all --error-exitcode=10101" CACHE STRING "options for valgrind tests")
    endif()
endfunction(c4_setup_valgrind)


function(c4_add_valgrind target_name)
    # @todo: consider doing this for valgrind:
    # http://stackoverflow.com/questions/40325957/how-do-i-add-valgrind-tests-to-my-cmake-test-target
    # for now we explicitly run it:
    if(${_c4_uprefix}VALGRIND)
        separate_arguments(_vg_opts UNIX_COMMAND "${${_c4_uprefix}VALGRIND_OPTIONS}")
        add_test(NAME ${target_name}-valgrind COMMAND valgrind ${_vg_opts} $<TARGET_FILE:${target_name}>)
    endif()
    if(${_c4_uprefix}VALGRIND_SGCHECK)
        # stack and global array overrun detector
        # http://valgrind.org/docs/manual/sg-manual.html
        separate_arguments(_sg_opts UNIX_COMMAND "--tool=exp-sgcheck ${${_c4_uprefix}VALGRIND_OPTIONS}")
        add_test(NAME ${target_name}-sgcheck COMMAND valgrind ${_sg_opts} $<TARGET_FILE:${target_name}>)
    endif()
endfunction(c4_add_valgrind)


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
function(c4_setup_coverage)
    set(_covok ON)
    if("${CMAKE_CXX_COMPILER_ID}" MATCHES "(Apple)?[Cc]lang")
        if("${CMAKE_CXX_COMPILER_VERSION}" VERSION_LESS 3)
	    message(STATUS "${_c4_prefix} coverage: clang version must be 3.0.0 or greater. No coverage available.")
            set(_covok OFF)
        endif()
    elseif(NOT CMAKE_COMPILER_IS_GNUCXX)
        if("${CMAKE_BUILD_TYPE}" STREQUAL "Coverage")
            message(FATAL_ERROR "${_c4_prefix} coverage: compiler is not GNUCXX. No coverage available.")
        endif()
        set(_covok OFF)
    endif()
    if(NOT _covok)
        return()
    endif()
    set(_covon OFF)
    if("${CMAKE_BUILD_TYPE}" STREQUAL "Coverage")
        set(_covon ON)
    endif()
    option(${_c4_uprefix}COVERAGE "enable coverage targets" ${_covon})
    cmake_dependent_option(${_c4_uprefix}COVERAGE_CODECOV "enable coverage with codecov" ON ${_c4_uprefix}COVERAGE OFF)
    cmake_dependent_option(${_c4_uprefix}COVERAGE_COVERALLS "enable coverage with coveralls" ON ${_c4_uprefix}COVERAGE OFF)
    if(${_c4_uprefix}COVERAGE)
        #set(covflags "-g -O0 -fprofile-arcs -ftest-coverage")
        set(covflags "-g -O0 --coverage")
        if(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
            set(covflags "${covflags} -fprofile-arcs -ftest-coverage -fno-inline -fno-inline-small-functions -fno-default-inline")
        endif()
        add_configuration_type(Coverage
            DEFAULT_FROM DEBUG
            C_FLAGS ${covflags}
            CXX_FLAGS ${covflags}
            )
        if("${CMAKE_BUILD_TYPE}" STREQUAL "Coverage")
            if(${_c4_uprefix}COVERAGE_CODECOV)
                #include(CodeCoverage)
            endif()
            if(${_c4_uprefix}COVERAGE_COVERALLS)
                #include(Coveralls)
                #coveralls_turn_on_coverage() # NOT NEEDED, we're doing this manually.
            endif()
            find_program(GCOV gcov)
            find_program(LCOV lcov)
            find_program(GENHTML genhtml)
            find_program(CTEST ctest)
            if(NOT (GCOV AND LCOV AND GENHTML AND CTEST))
                if (HAVE_CXX_FLAG_COVERAGE)
                    set(CXX_FLAG_COVERAGE_MESSAGE supported)
                else()
                    set(CXX_FLAG_COVERAGE_MESSAGE unavailable)
                endif()
                message(WARNING
                    "Coverage not available:\n"
                    "  gcov: ${GCOV}\n"
                    "  lcov: ${LCOV}\n"
                    "  genhtml: ${GENHTML}\n"
                    "  ctest: ${CTEST}\n"
                    "  --coverage flag: ${CXX_FLAG_COVERAGE_MESSAGE}")
            endif()
            add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/lcov/index.html
                COMMAND ${LCOV} -q --zerocounters --directory .
                COMMAND ${LCOV} -q --no-external --capture --base-directory "${CMAKE_SOURCE_DIR}" --directory . --output-file before.lcov --initial
                COMMAND ${CTEST} --force-new-ctest-process
                COMMAND ${LCOV} -q --no-external --capture --base-directory "${CMAKE_SOURCE_DIR}" --directory . --output-file after.lcov
                COMMAND ${LCOV} -q --add-tracefile before.lcov --add-tracefile after.lcov --output-file final.lcov
                COMMAND ${LCOV} -q --remove final.lcov "'${CMAKE_SOURCE_DIR}/test/*'" "'/usr/*'" "'*/extern/*'" --output-file final.lcov
                COMMAND ${GENHTML} final.lcov -o lcov --demangle-cpp --sort -p "${CMAKE_BINARY_DIR}" -t ${_c4_lcprefix}
                #DEPENDS ${_c4_lprefix}test
                WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
                COMMENT "${_c4_prefix} coverage: Running LCOV"
                )
            add_custom_target(${_c4_lprefix}coverage
                DEPENDS ${CMAKE_BINARY_DIR}/lcov/index.html
                COMMENT "${_c4_lcprefix} coverage: LCOV report at ${CMAKE_BINARY_DIR}/lcov/index.html"
                )
            message(STATUS "Coverage command added")
        endif()
    endif()
endfunction(c4_setup_coverage)


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
function(c4_setup_benchmarking)
    c4_log("enabling benchmarks: to build, ${_c4_lprefix}bm-build")
    c4_log("enabling benchmarks: to run, ${_c4_lprefix}bm")
    # umbrella target for building test binaries
    add_custom_target(${_c4_lprefix}bm-build)
    # umbrella target for running benchmarks
    add_custom_target(${_c4_lprefix}bm
        ${CMAKE_COMMAND} -E echo CWD=${CMAKE_BINARY_DIR}
        DEPENDS ${_c4_lprefix}bm-build
        )
    _c4_set_target_folder(${_c4_lprefix}bm-build ${_c4_lprefix}bm)
    _c4_set_target_folder(${_c4_lprefix}bm ${_c4_lprefix}bm)
    # download google benchmark
    if(NOT TARGET benchmark)
        c4_override(BENCHMARK_ENABLE_TESTING OFF)
        c4_override(BENCHMARK_ENABLE_EXCEPTIONS OFF)
        c4_override(BENCHMARK_ENABLE_LTO OFF)
        c4_import_remote_proj(googlebenchmark ${CMAKE_CURRENT_BINARY_DIR}/extern/googlebenchmark
            GIT_REPOSITORY https://github.com/google/benchmark.git
            )
        c4_set_folder_remote_project_targets(${_c4_lprefix}bm benchmark benchmark_main)
    endif()
    #
    if(CMAKE_COMPILER_IS_GNUCC)
        target_compile_options(benchmark PRIVATE -Wno-deprecated-declarations)
    endif()
    #
    if(NOT WIN32)
        option(${_c4_uprefix}BENCHMARK_CPUPOWER
            "set the cpu mode to performance before / powersave after the benchmark" OFF)
        if(${_c4_uprefix}BENCHMARK_CPUPOWER)
            find_program(C4_SUDO sudo)
            find_program(C4_CPUPOWER cpupower)
        endif()
    endif()
endfunction()


function(c4_add_benchmark_cmd casename)
    add_custom_target(${casename}
        COMMAND ${ARGN}
        VERBATIM
        COMMENT "${_c4_prefix}: running benchmark ${casename}: ${ARGN}")
    add_dependencies(${_c4_lprefix}benchmark ${casename})
    _c4_set_target_folder(${casename} ${_c4_lprefix}bm)
endfunction()


# assumes this is a googlebenchmark target, and that multiple
# benchmarks are defined from it
function(c4_add_target_benchmark target casename)
    set(opt0arg
    )
    set(opt1arg
        WORKDIR # working directory
        FILTER  # benchmark patterns to filter
    )
    set(optnarg
        ARGS
    )
    cmake_parse_arguments("" "${opt0arg}" "${opt1arg}" "${optnarg}" ${ARGN})
    #
    set(name "${target}-${casename}")
    set(rdir "${CMAKE_CURRENT_BINARY_DIR}/bm-results")
    set(rfile "${rdir}/${name}.json")
    if(NOT EXISTS "${rdir}")
        file(MAKE_DIRECTORY "${rdir}")
    endif()
    set(filter)
    if(NOT ("${_FILTER}" STREQUAL ""))
        set(filter "--benchmark_filter=${_FILTER}")
    endif()
    set(args_fwd ${filter} --benchmark_out_format=json --benchmark_out=${rfile} ${_ARGS})
    c4_add_benchmark(${target}
        "${name}"
        "${_WORKDIR}"
        "saving results in ${rfile}"
        ${args_fwd})
endfunction()


function(c4_add_benchmark target casename work_dir comment)
    if(NOT TARGET ${target})
        message(FATAL_ERROR "target ${target} does not exist...")
    endif()
    if(NOT ("${work_dir}" STREQUAL ""))
        if(NOT EXISTS "${work_dir}")
            file(MAKE_DIRECTORY "${work_dir}")
        endif()
    endif()
    set(exe $<TARGET_FILE:${target}>)
    if(${_c4_uprefix}BENCHMARK_CPUPOWER)
        if(C4_BM_SUDO AND C4_BM_CPUPOWER)
            set(c ${C4_SUDO} ${C4_CPUPOWER} frequency-set --governor performance)
            set(cpupow_before
                COMMAND echo ${c}
                COMMAND ${c})
            set(c ${C4_SUDO} ${C4_CPUPOWER} frequency-set --governor powersave)
            set(cpupow_after
                COMMAND echo ${c}
                COMMAND ${c})
        endif()
    endif()
    add_custom_target(${casename}
        ${cpupow_before}
        # this is useful to show the target file (you cannot echo generator variables)
        #COMMAND ${CMAKE_COMMAND} -E echo "target file = $<TARGET_FILE:${target}>"
        COMMAND ${CMAKE_COMMAND} -E echo "${exe} ${ARGN}"
        COMMAND "${exe}" ${ARGN}
        ${cpupow_after}
        VERBATIM
        WORKING_DIRECTORY "${work_dir}"
        DEPENDS ${target}
        COMMENT "${_c4_lcprefix}: running benchmark ${target}, case ${casename}: ${comment}"
        )
    add_dependencies(${_c4_lprefix}bm-build ${target})
    add_dependencies(${_c4_lprefix}bm ${casename})
    _c4_set_target_folder(${casename} ${_c4_lprefix}bm)
endfunction()



#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#

#
# https://steveire.wordpress.com/2016/08/09/opt-in-header-only-libraries-with-cmake/
#
# Transform types:
#   * NONE
#   * UNITY
#   * UNITY_HDR
#   * SINGLE_HDR
#   * SINGLE_UNIT
function(c4_add_target_sources target)
    set(options0arg
    )
    set(options1arg
        TRANSFORM
    )
    set(optionsnarg
        PUBLIC
        INTERFACE
        PRIVATE
    )
    cmake_parse_arguments("" "${options0arg}" "${options1arg}" "${optionsnarg}" ${ARGN})
    if(("${_TRANSFORM}" STREQUAL "GLOBAL") OR ("${_TRANSFORM}" STREQUAL ""))
        set(_TRANSFORM ${C4_SOURCE_TRANSFORM})
    endif()
    if("${_TRANSFORM}" STREQUAL "")
        set(_TRANSFORM NONE)
    endif()
    #
    # is this target an interface?
    set(_is_iface FALSE)
    get_target_property(target_type ${target} TYPE)
    if("${target_type}" STREQUAL "INTERFACE_LIBRARY")
        set(_is_iface TRUE)
    elseif("${prop_name}" STREQUAL "LINK_LIBRARIES")
        set(_is_iface FALSE)
    endif()
    #
    set(out)
    set(umbrella ${_c4_lprefix}transform-src)
    #
    if("${_TRANSFORM}" STREQUAL "NONE")
        c4_dbg("target=${target} source transform: NONE!")
        #
        # do not transform the sources
        #
        if(_PUBLIC)
            c4_dbg("target=${target} PUBLIC sources: ${_PUBLIC}")
            target_sources(${target} PUBLIC ${_PUBLIC})
        endif()
        if(_INTERFACE)
            c4_dbg("target=${target} INTERFACE sources: ${_INTERFACE}")
            target_sources(${target} INTERFACE ${_INTERFACE})
        endif()
        if(_PRIVATE)
            c4_dbg("target=${target} PRIVATE sources: ${_PRIVATE}")
            target_sources(${target} PRIVATE ${_PRIVATE})
        endif()
        #
    elseif("${_TRANSFORM}" STREQUAL "UNITY")
        c4_dbg("source transform: UNITY!")
        message(FATAL_ERROR "source transformation not implemented")
        #
        # concatenate all compilation unit files (excluding interface)
        # into a single compilation unit
        #
        _c4cat_filter_srcs("${_PUBLIC}"    cpublic)
        _c4cat_filter_hdrs("${_PUBLIC}"    hpublic)
        _c4cat_filter_srcs("${_INTERFACE}" cinterface)
        _c4cat_filter_hdrs("${_INTERFACE}" hinterface)
        _c4cat_filter_srcs("${_PRIVATE}"   cprivate)
        _c4cat_filter_hdrs("${_PRIVATE}"   hprivate)
        if(cpublic OR cinterface OR cprivate)
            _c4cat_get_outname(${target} "src" ${C4_GEN_SRC_EXT} out)
            c4_dbg("${target}: output unit: ${out}")
            c4_cat_sources("${cpublic};${cinterface};${cprivate}" "${out}" ${umbrella})
            add_dependencies(${target} ${out})
        endif()
        if(_PUBLIC)
            target_sources(${target} PUBLIC
                $<BUILD_INTERFACE:${hpublic};${out}>
                $<INSTALL_INTERFACE:${hpublic};${out}>)
        endif()
        if(_INTERFACE)
            target_sources(${target} INTERFACE
                $<BUILD_INTERFACE:${hinterface}>
                $<INSTALL_INTERFACE:${hinterface}>)
        endif()
        if(_PRIVATE)
            target_sources(${target} PRIVATE
                $<BUILD_INTERFACE:${hprivate}>
                $<INSTALL_INTERFACE:${hprivate}>)
        endif()
        #
    elseif("${_TRANSFORM}" STREQUAL "UNITY_HDR")
        c4_dbg("source transform: UNITY_HDR!")
        message(FATAL_ERROR "source transformation not implemented")
        #
        # like unity, but concatenate compilation units into
        # a header file, leaving other header files untouched
        #
        _c4cat_filter_srcs("${_PUBLIC}"    cpublic)
        _c4cat_filter_hdrs("${_PUBLIC}"    hpublic)
        _c4cat_filter_srcs("${_INTERFACE}" cinterface)
        _c4cat_filter_hdrs("${_INTERFACE}" hinterface)
        _c4cat_filter_srcs("${_PRIVATE}"   cprivate)
        _c4cat_filter_hdrs("${_PRIVATE}"   hprivate)
        if(c)
            _c4cat_get_outname(${target} "src" ${C4_GEN_HDR_EXT} out)
            c4_dbg("${target}: output hdr: ${out}")
            _c4cat_filter_srcs_hdrs("${_PUBLIC}" c_h)
            c4_cat_sources("${c}" "${out}" ${umbrella})
            add_dependencies(${target} ${out})
            add_dependencies(${target} ${_c4_lprefix}cat)
        endif()
        set(${src} ${out} PARENT_SCOPE)
        set(${hdr} ${h} PARENT_SCOPE)
        #
    elseif("${_TRANSFORM}" STREQUAL "SINGLE_HDR")
        c4_dbg("source transform: SINGLE_HDR!")
        message(FATAL_ERROR "source transformation not implemented")
        #
        # concatenate everything into a single header file
        #
        _c4cat_get_outname(${target} "all" ${C4_GEN_HDR_EXT} out)
        _c4cat_filter_srcs_hdrs("${_c4al_SOURCES}" ch)
        c4_cat_sources("${ch}" "${out}" ${umbrella})
        #
    elseif("${_TRANSFORM}" STREQUAL "SINGLE_UNIT")
        c4_dbg("source transform: SINGLE_HDR!")
        message(FATAL_ERROR "source transformation not implemented")
        #
        # concatenate:
        #  * all compilation unit into a single compilation unit
        #  * all headers into a single header
        #
        _c4cat_get_outname(${target} "src" ${C4_GEN_SRC_EXT} out)
        _c4cat_get_outname(${target} "hdr" ${C4_GEN_SRC_EXT} out)
        _c4cat_filter_srcs_hdrs("${_c4al_SOURCES}" ch)
        c4_cat_sources("${ch}" "${out}" ${umbrella})
    else()
        message(FATAL_ERROR "unknown transform type: ${transform_type}. Must be one of GLOBAL;NONE;UNITY;TO_HEADERS;SINGLE_HEADER")
    endif()
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

function(_c4cat_get_outname target id ext out)
    if("${_c4_lcprefix}" STREQUAL "${target}")
        set(p "${target}")
    else()
        set(p "${_c4_lcprefix}.${target}")
    endif()
    set(${out} "${CMAKE_CURRENT_BINARY_DIR}/${p}.${id}.${ext}" PARENT_SCOPE)
endfunction()

function(_c4cat_filter_srcs in out)
    _c4cat_filter_extensions("${in}" "${C4_SRC_EXTS}" l)
    set(${out} ${l} PARENT_SCOPE)
endfunction()

function(_c4cat_filter_hdrs in out)
    _c4cat_filter_extensions("${in}" "${C4_HDR_EXTS}" l)
    set(${out} ${l} PARENT_SCOPE)
endfunction()

function(_c4cat_filter_srcs_hdrs in out)
    _c4cat_filter_extensions("${in}" "${C4_HDR_EXTS};${C4_SRC_EXTS}" l)
    set(${out} ${l} PARENT_SCOPE)
endfunction()

function(_c4cat_filter_extensions in filter out)
    set(l)
    foreach(fn ${in})  # don't quote the list here
        _c4cat_get_file_ext("${fn}" ext)
        _c4cat_one_of("${ext}" "${filter}" yes)
        if(${yes})
            list(APPEND l "${fn}")
        endif()
    endforeach()
    set(${out} "${l}" PARENT_SCOPE)
endfunction()

function(_c4cat_get_file_ext in out)
    # https://stackoverflow.com/questions/30049180/strip-filename-shortest-extension-by-cmake-get-filename-removing-the-last-ext
    string(REGEX MATCH "^.*\\.([^.]*)$" dummy ${in})
    set(${out} ${CMAKE_MATCH_1} PARENT_SCOPE)
endfunction()

function(_c4cat_one_of ext candidates out)
    foreach(e ${candidates})
        if(ext STREQUAL ${e})
            set(${out} YES PARENT_SCOPE)
            return()
        endif()
    endforeach()
    set(${out} NO PARENT_SCOPE)
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# given a list of source files, return a list with full paths
function(c4_to_full_path source_list source_list_with_full_paths)
    set(l)
    foreach(f ${source_list})
        if(IS_ABSOLUTE "${f}")
            list(APPEND l "${f}")
        else()
            list(APPEND l "${CMAKE_CURRENT_SOURCE_DIR}/${f}")
        endif()
    endforeach()
    set(${source_list_with_full_paths} ${l} PARENT_SCOPE)
endfunction()


# convert a list to a string separated with spaces
function(c4_separate_list input_list output_string)
    set(s)
    foreach(e ${input_list})
        set(s "${s} ${e}")
    endforeach()
    set(${output_string} ${s} PARENT_SCOPE)
endfunction()



#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
endif(NOT _c4_project_included)
