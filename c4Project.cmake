if(NOT _c4_project_included)
set(_c4_project_included ON)
set(_c4_project_file ${CMAKE_CURRENT_LIST_FILE})
set(_c4_project_dir  ${CMAKE_CURRENT_LIST_DIR})


# "I didn't have time to write a short letter, so I wrote a long one
# instead." -- Mark Twain
#
# ... Eg, hopefully this code will be cleaned up. There's a lot of
# code here that can be streamlined into a more intuitive arrangement.


cmake_minimum_required(VERSION 3.12 FATAL_ERROR)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

include(CMakeDependentOption)
include(ConfigurationTypes)
include(CreateSourceGroup)
include(c4StaticAnalysis)
include(PrintVar)
include(c4CatSources)
include(c4Doxygen)
include(PatchUtils)


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
set(C4_ADD_EXTS "natvis" CACHE STRING "list of additional file extensions that might be added as sources to targets")
set(C4_GEN_SRC_EXT "cpp" CACHE STRING "the extension of the output source files resulting from concatenation")
set(C4_GEN_HDR_EXT "hpp" CACHE STRING "the extension of the output header files resulting from concatenation")
set(C4_CXX_STANDARDS "20;17;14;11" CACHE STRING "list of CXX standards")
set(C4_CXX_STANDARD_DEFAULT "11" CACHE STRING "the default CXX standard for projects not specifying one")


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

macro(c4_log)
    message(STATUS "${_c4_prefix}: ${ARGN}")
endmacro()


macro(c4_err)
    message(FATAL_ERROR "${_c4_prefix}: ${ARGN}")
endmacro()


macro(c4_dbg)
    if(C4_DBG_ENABLED)
        message(STATUS "${_c4_prefix}: ${ARGN}")
    endif()
endmacro()


macro(c4_log_var varname)
    c4_log("${varname}=${${varname}} ${ARGN}")
endmacro()
macro(c4_log_vars)
    set(____s____)
    foreach(varname ${ARGN})
        set(____s____ "${____s____}${varname}=${${varname}} ")
    endforeach()
    c4_log("${____s____}")
endmacro()
macro(c4_dbg_var varname)
    c4_dbg("${varname}=${${varname}} ${ARGN}")
endmacro()
macro(c4_log_var_if varname)
    if(${varname})
        c4_log("${varname}=${${varname}} ${ARGN}")
    endif()
endmacro()
macro(c4_dbg_var_if varname)
    if(${varname})
        c4_dbg("${varname}=${${varname}} ${ARGN}")
    endif()
endmacro()


macro(_c4_show_pfx_vars)
    if(NOT ("${ARGN}" STREQUAL ""))
        c4_log("prefix vars: ${ARGN}")
    endif()
    print_var(_c4_prefix)
    print_var(_c4_ocprefix)
    print_var(_c4_ucprefix)
    print_var(_c4_lcprefix)
    print_var(_c4_oprefix)
    print_var(_c4_uprefix)
    print_var(_c4_lprefix)
endmacro()


function(c4_zero_pad padded size str)
    string(LENGTH "${str}" len)
    math(EXPR numchars "${size} - ${len}")
    if(numchars EQUAL 0)
        set(${padded} "${str}" PARENT_SCOPE)
    else()
        set(out "${str}")
        math(EXPR ncm1 "${numchars} - 1")
        foreach(z RANGE ${ncm1})
            set(out "0${out}")
        endforeach()
        set(${padded} "${out}" PARENT_SCOPE)
    endif()
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# handy macro for dealing with arguments in one single statement.
# look for example usage cases below.
macro(_c4_handle_args)
    set(opt0arg
    )
    set(opt1arg
        _PREFIX
    )
    set(optNarg
        _ARGS0
        _ARGS1
        _ARGSN
        _ARGS
        _DEPRECATE
    )
    # parse the arguments to this macro to find out the required arguments
    cmake_parse_arguments("__c4ha" "${opt0arg}" "${opt1arg}" "${optNarg}" ${ARGN})
    # now parse the required arguments
    cmake_parse_arguments("${__c4ha__PREFIX}" "${__c4ha__ARGS0}" "${__c4ha__ARGS1}" "${__c4ha__ARGSN}" ${__c4ha__ARGS})
    # raise an error on deprecated arguments
    foreach(a ${__c4ha__DEPRECATE})
        list(FIND __c4ha__ARGS ${a} contains)
        if(NOT (${contains} EQUAL -1))
            c4err("${a} is deprecated")
        endif()
    endforeach()
endmacro()

# fallback to provided default(s) if argument is not set
macro(_c4_handle_arg argname)
     if("${_${argname}}" STREQUAL "")
         set(_${argname} "${ARGN}")
     else()
         set(_${argname} "${_${argname}}")
     endif()
endmacro()
macro(_c4_handle_arg_no_pfx argname)
     if("${${argname}}" STREQUAL "")
         set(${argname} "${ARGN}")
     else()
         set(${argname} "${${argname}}")
     endif()
endmacro()


# if ${_${argname}} is non empty, return it
# otherwise, fallback to ${_c4_uprefix}${argname}
# otherwise, fallback to C4_${argname}
# otherwise, fallback to provided default through ${ARGN}
macro(_c4_handle_arg_or_fallback argname)
    if(NOT ("${_${argname}}" STREQUAL ""))
        c4_dbg("handle arg ${argname}: picking explicit value _${argname}=${_${argname}}")
    else()
        foreach(_c4haf_varname "${_c4_uprefix}${argname}" "C4_${argname}" "${argname}" "CMAKE_${argname}")
            set(v ${${_c4haf_varname}})
            if("${v}" STREQUAL "")
                c4_dbg("handle arg ${argname}: ${_c4haf_varname}: empty, continuing")
            else()
                c4_dbg("handle arg ${argname}: ${_c4haf_varname}=${v} not empty!")
                c4_setg(_${argname} "${v}")
                break()
            endif()
        endforeach()
        if("${_${argname}}" STREQUAL "")
            c4_dbg("handle arg ${argname}: picking default: ${ARGN}")
            c4_setg(_${argname} "${ARGN}")
        endif()
    endif()
endmacro()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

function(c4_get_config var name)
    c4_dbg("get_config: ${var} ${name}")
    c4_get_from_first_of(config ${ARGN} VARS ${_c4_uprefix}${name} C4_${name} ${name})
    c4_dbg("get_config: ${var} ${name}=${config}")
    set(${var} ${config} PARENT_SCOPE)
endfunction()


function(c4_get_from_first_of var)
    _c4_handle_args(_ARGS ${ARGN}
        _ARGS0
            REQUIRED  # raise an error if no set variable was found
            ENV  # if none of the provided vars is given,
                 # then search next on environment variables
                 # of the same name, using the same sequence
        _ARGS1
            DEFAULT
        _ARGSN
            VARS
    )
    c4_dbg("get_from_first_of(): searching ${var}")
    foreach(_var ${_VARS})
        set(val ${${_var}})
        c4_dbg("${var}: searching ${_var}=${val}")
        if(NOT ("${val}" STREQUAL ""))
            set(${var} "${val}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
    if(_ENV)
        foreach(_envvar ${_VARS})
            set(val $ENV{${_envvar}})
            c4_dbg("${var}: searching environment variable ${_envvar}=${val}")
            if(NOT ("${val}" STREQUAL ""))
                c4_dbg("${var}: picking ${val} from ${_envvar}")
                set(${var} "${val}" PARENT_SCOPE)
                return()
            endif()
        endforeach()
    endif()
    if(_REQUIRED)
        c4_err("could not find a value for the variable ${var}")
    endif()
    set(${var} ${_DEFAULT} PARENT_SCOPE)
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# assumes a prior call to project()
function(c4_project)
    _c4_handle_args(_ARGS ${ARGN}
      _ARGS0  # zero-value macro arguments
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
      _ARGS1  # one-value macro arguments
        AUTHOR        # specify author(s); used in cpack
        VERSION       # cmake does not accept semantic versioning so we provide
                      # that here (see https://gitlab.kitware.com/cmake/cmake/-/issues/16716)
        CXX_STANDARD  # one of latest;${C4_VALID_CXX_STANDARDS}
                      # if this is not provided, falls back on
                      # ${uprefix}CXX_STANDARD, then C4_CXX_STANDARD,
                      # then CXX_STANDARD. if none are provided,
                      # defaults to 11
      _ARGSN  # multi-value macro arguments
    )
    # get the prefix from the call to project()
    set(prefix ${PROJECT_NAME})
    string(TOUPPER "${prefix}" ucprefix) # ucprefix := upper case prefix
    string(TOLOWER "${prefix}" lcprefix) # lcprefix := lower case prefix
    if(NOT _c4_prefix)
        c4_setg(_c4_is_root_proj ON)
        c4_setg(_c4_root_proj ${prefix})
        c4_setg(_c4_root_uproj ${ucprefix})
        c4_setg(_c4_root_lproj ${lcprefix})
        c4_setg(_c4_curr_path "")
    else()
        c4_setg(_c4_is_root_proj OFF)
        if(_c4_curr_path)
            c4_setg(_c4_curr_path "${_c4_curr_path}/${prefix}")
        else()
            c4_setg(_c4_curr_path "${prefix}")
        endif()
    endif()
    c4_setg(_c4_curr_subproject ${prefix})
    # get the several prefix flavors
    c4_setg(_c4_ucprefix ${ucprefix})
    c4_setg(_c4_lcprefix ${lcprefix})
    c4_setg(_c4_ocprefix ${prefix})              # ocprefix := original case prefix
    c4_setg(_c4_prefix   ${prefix})              # prefix := original prefix
    c4_setg(_c4_oprefix  ${prefix})              # oprefix := original prefix
    c4_setg(_c4_uprefix  ${_c4_ucprefix})        # upper prefix: for variables
    c4_setg(_c4_lprefix  ${_c4_lcprefix})        # lower prefix: for targets
    if(_c4_oprefix)
        c4_setg(_c4_oprefix "${_c4_oprefix}_")
    endif()
    if(_c4_uprefix)
        c4_setg(_c4_uprefix "${_c4_uprefix}_")
    endif()
    if(_c4_lprefix)
        c4_setg(_c4_lprefix "${_c4_lprefix}-")
    endif()
    #
    if(_STANDALONE)
        option(${_c4_uprefix}STANDALONE
            "Enable compilation of opting-in targets from ${_c4_lcprefix} in standalone mode (ie, incorporate subprojects as specified in the INCORPORATE clause to c4_add_library/c4_add_target)"
            ${_c4_is_root_proj})
        c4_setg(_c4_root_proj_standalone ${_c4_uprefix}STANDALONE)
    endif()
    _c4_handle_arg_or_fallback(CXX_STANDARD ${C4_CXX_STANDARD_DEFAULT})
    _c4_handle_arg(VERSION 0.0.0-pre0)
    _c4_handle_arg(AUTHOR "")
    _c4_handle_semantic_version(${_VERSION})
    #
    # make sure project-wide settings are defined -- see cmake's
    # documentation for project(), which defines these and other
    # variables
    if("${PROJECT_DESCRIPTION}" STREQUAL "")
        c4_setg(PROJECT_DESCRIPTION "${prefix}")
        c4_setg(${prefix}_DESCRIPTION "${prefix}")
    endif()
    if("${PROJECT_HOMEPAGE_URL}" STREQUAL "")
        c4_setg(PROJECT_HOMEPAGE_URL "")
        c4_setg(${prefix}_HOMEPAGE_URL "")
    endif()
    # other specific c4_project properties
    c4_setg(PROJECT_AUTHOR "${_AUTHOR}")
    c4_setg(${prefix}_AUTHOR "${_AUTHOR}")

    # CXX standard
    if("${_CXX_STANDARD}" STREQUAL "latest")
        _c4_find_latest_supported_cxx_standard(_CXX_STANDARD)
    endif()
    c4_log("using C++ standard: C++${_CXX_STANDARD}")
    c4_set_proj_prop(CXX_STANDARD "${_CXX_STANDARD}")
    c4_setg(${_c4_uprefix}CXX_STANDARD "${_CXX_STANDARD}")
    if(${_CXX_STANDARD})
        c4_set_cxx(${_CXX_STANDARD})
    endif()

    # we are opinionated with respect to directory structure
    c4_setg(${_c4_uprefix}SRC_DIR ${CMAKE_CURRENT_LIST_DIR}/src)
    c4_setg(${_c4_uprefix}EXT_DIR ${CMAKE_CURRENT_LIST_DIR}/ext)
    c4_setg(${_c4_uprefix}API_DIR ${CMAKE_CURRENT_LIST_DIR}/api)
    # opionionated also for directory test
    # opionionated also for directory bm (benchmarks)

    if("${C4_DEV}" STREQUAL "")
        option(C4_DEV "enable development targets for all c4 projects" OFF)
    endif()
    option(${_c4_uprefix}DEV "enable development targets: tests, benchmarks, static analysis, coverage" ${C4_DEV})

    if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/test")
        cmake_dependent_option(${_c4_uprefix}BUILD_TESTS "build unit tests" ON ${_c4_uprefix}DEV OFF)
    else()
        c4_dbg("no tests: directory does not exist: ${CMAKE_CURRENT_LIST_DIR}/test")
    endif()
    if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/bm")
        cmake_dependent_option(${_c4_uprefix}BUILD_BENCHMARKS "build benchmarks" ON ${_c4_uprefix}DEV OFF)
    else()
        c4_dbg("no benchmarks: directory does not exist: ${CMAKE_CURRENT_LIST_DIR}/bm")
    endif()
    if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/api")
        cmake_dependent_option(${_c4_uprefix}BUILD_API "build API" OFF ${_c4_uprefix}DEV OFF)
    else()
        c4_dbg("no API generation: directory does not exist: ${CMAKE_CURRENT_LIST_DIR}/api")
    endif()
    if(_c4_is_root_proj)
        c4_setup_coverage()
    endif()
    c4_setup_sanitize()
    c4_setup_valgrind(${_c4_uprefix}DEV)
    c4_setup_static_analysis(${_c4_uprefix}DEV)
    c4_setup_doxygen(${_c4_uprefix}DEV)

    # option to use libc++
    option(${_c4_uprefix}USE_LIBCXX "use libc++ instead of the default standard library" OFF)
    if(${_c4_uprefix}USE_LIBCXX)
        if(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
            c4_log("using libc++")
            list(APPEND CMAKE_CXX_FLAGS           -stdlib=libc++)
            list(APPEND CMAKE_EXE_LINKER_FLAGS    -lc++)
            list(APPEND CMAKE_MODULE_LINKER_FLAGS -lc++)
            list(APPEND CMAKE_SHARED_LINKER_FLAGS -lc++)
            list(APPEND CMAKE_STATIC_LINKER_FLAGS -lc++)
        else()
            c4_err("libc++ can only be used with clang")
        endif()
    endif()

    # default compilation flags
    set(${_c4_uprefix}CXX_FLAGS "${${_c4_uprefix}CXX_FLAGS_FWD}" CACHE STRING "compilation flags for ${_c4_prefix} targets")
    set(${_c4_uprefix}CXX_LINKER_FLAGS "${${_c4_uprefix}CXX_LINKER_FLAGS_FWD}" CACHE STRING "linker flags for ${_c4_prefix} targets")
    c4_dbg_var_if(${_c4_uprefix}CXX_LINKER_FLAGS_FWD)
    c4_dbg_var_if(${_c4_uprefix}CXX_FLAGS_FWD)
    c4_dbg_var_if(${_c4_uprefix}CXX_LINKER_FLAGS)
    c4_dbg_var_if(${_c4_uprefix}CXX_FLAGS)

    # Dev compilation flags, appended to the project's flags. They
    # are enabled when in dev mode, but provided as a (default-disabled)
    # option when not in dev mode
    c4_dbg_var_if(${_c4_uprefix}CXX_FLAGS_OPT_FWD)
    c4_setg(${_c4_uprefix}CXX_FLAGS_OPT "${${_c4_uprefix}CXX_FLAGS_OPT_FWD}")
    c4_optional_compile_flags_dev(WERROR "Compile with warnings as errors"
        GCC_CLANG -Werror -pedantic-errors
        MSVC /WX
        )
    c4_optional_compile_flags_dev(STRICT_ALIASING "Enable strict aliasing"
        GCC_CLANG -fstrict-aliasing
        MSVC # does it have this?
        )
    c4_optional_compile_flags_dev(PEDANTIC "Compile in pedantic mode"
        GCC ${_C4_PEDANTIC_FLAGS_GCC}
        CLANG ${_C4_PEDANTIC_FLAGS_CLANG}
        MSVC ${_C4_PEDANTIC_FLAGS_MSVC}
        )
    c4_dbg_var_if(${_c4_uprefix}CXX_FLAGS_OPT)
endfunction(c4_project)


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

macro(c4_setup_sanitize)
    if(CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
        set(_c4_enable_sanitize ON)
        if(NOT ((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang") OR (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")))
            set(_c4_enable_sanitize OFF)
        endif()
        if("${CMAKE_BUILD_TYPE}" STREQUAL "Coverage")
            set(_c4_enable_sanitize OFF)
        endif()
        if(_c4_enable_sanitize)
            if("${CMAKE_BUILD_TYPE}" STREQUAL "")
                set(CMAKE_BUILD_TYPE Release)
            endif()
            if(CMAKE_C_COMPILER_ID STREQUAL "GNU")  # is there coverage?
                set(CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE} CACHE
                    STRING "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel Coverage tsan asan lsan msan ubsan" FORCE)
            else()
                set(CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE} CACHE
                    STRING "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel tsan asan lsan msan ubsan" FORCE)
            endif()
            _c4_add_sanitizer_build_type(AddressSanitizer ASAN
                # https://clang.llvm.org/docs/AddressSanitizer.html
                "-fsanitize=address -g -O1 -fno-omit-frame-pointer -fno-optimize-sibling-calls -fsanitize-address-use-after-scope -DC4_ASAN"
            )
            _c4_add_sanitizer_build_type(LeakSanitizer LSAN
                # https://clang.llvm.org/docs/LeakSanitizer.html
                "-fsanitize=leak -g -O1 -fno-omit-frame-pointer -DC4_LSAN"
            )
            if(NOT (CMAKE_CXX_COMPILER_ID STREQUAL "GNU"))
                _c4_add_sanitizer_build_type(MemorySanitizer MSAN
                    # https://clang.llvm.org/docs/MemorySanitizer.html
                    "-fsanitize=memory -g -O1 -fno-omit-frame-pointer -fno-optimize-sibling-calls -fsanitize-memory-track-origins=2 -DC4_MSAN"
                )
            endif()
            _c4_add_sanitizer_build_type(ThreadSanitizer TSAN
                # https://clang.llvm.org/docs/ThreadSanitizer.html
                "-fsanitize=thread -g -O1 -DC4_TSAN"
            )
            _c4_add_sanitizer_build_type(UndefinedBehaviorSanitizer UBSAN
                # https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html
                "-fsanitize=undefined -g -O1 -fno-omit-frame-pointer -DC4_UBSAN"
                # these flags added only in the CLANG ubsan
                CLANG "-fsanitize=implicit-conversion -fsanitize=local-bounds"
            )
        endif()
    endif()
endmacro()


function(_c4_add_sanitizer_build_type sanitizer build_type _sanflags)
    # add compiler-specific flags
    cmake_parse_arguments("" "" "" "GCC CLANG" ${ARGN})
    if((CMAKE_CXX_COMPILER_ID STREQUAL "Clang") OR (CMAKE_CXX_COMPILER_ID STREQUAL "GNU"))
        set(_sanflags "${_sanflags} ${_CLANG}")
    elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        set(_sanflags "${_sanflags} ${_GCC}")
    endif()
    # force an error exit when any problem is detected:
    set(_sanflags "${_sanflags} -fno-sanitize-recover=all")
    # add a suppression file
    set(do_it ON)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        if(${sanitizer} STREQUAL MemorySanitizer)
            set(do_it ON)
        else()
            set(do_it OFF)
        endif()
    endif()
    if(do_it)
        set(supprfile ${CMAKE_BINARY_DIR}/c4_suppressions_${sanitizer}.txt)
        file(WRITE ${supprfile})
        set(_sanflags "${_sanflags} -fsanitize-ignorelist=${supprfile}")
    endif()
    # set the compile flags
    set(CMAKE_C_FLAGS_${build_type} "${_sanflags}" CACHE
        STRING "Flags used by the C compiler on ${sanitizer} builds." FORCE)
    set(CMAKE_CXX_FLAGS_${build_type} "${_sanflags}" CACHE
        STRING "Flags used by the C++ compiler on ${sanitizer} builds." FORCE)
    # need to link using the compiler, and not ld
    string(TOUPPER "${CMAKE_BUILD_TYPE}" upper)
    if("${upper}" STREQUAL "${build_type}")
        set(CMAKE_LINKER ${CMAKE_CXX_COMPILER} CACHE FILEPATH "Linker" FORCE)
        set(SANITIZER_ENVIRONMENT "${upper}_OPTIONS=print_stacktrace=1" PARENT_SCOPE)
    endif()
    # this is not needed because we're using the C compiler to link,
    # and CMAKE_C_FLAGS will be used with it:
    #set(CMAKE_EXE_LINKER_FLAGS_${build_type} "${_sanflags}" CACHE
    #    STRING "Flags used by the linker on ${sanitizer} builds." FORCE)
endfunction()


function(c4_add_sanitizer_suppression sanitizer suppression)
    set(supprfile ${CMAKE_BINARY_DIR}/c4_suppressions_${sanitizer}.txt)
    file(APPEND ${supprfile} "#
${suppression}
")
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# cmake: VERSION argument in project() does not accept semantic versioning
# see: https://gitlab.kitware.com/cmake/cmake/-/issues/16716
macro(_c4_handle_semantic_version version)
    # https://stackoverflow.com/questions/18658233/split-string-to-3-variables-in-cmake
    string(REPLACE "." ";" version_list ${version})
    list(GET version_list 0 _major)
    list(GET version_list 1 _minor)
    list(GET version_list 2 _patch)
    if("${_patch}" STREQUAL "")
        set(_patch 1)
        set(_tweak)
    else()
        string(REGEX REPLACE "([0-9]+)[-_.]?(.*)" "\\2" _tweak ${_patch}) # do this first
        string(REGEX REPLACE "([0-9]+)[-_.]?(.*)" "\\1" _patch ${_patch}) # ... because this replaces _patch
    endif()
    # because cmake handles only numeric tweak fields, make sure to skip our
    # semantic tweak field if it is not numeric
    if(${_tweak} MATCHES "^[0-9]+$")
        set(_safe_tweak ${_tweak})
        set(_safe_version ${_major}.${_minor}.${_patch}.${_tweak})
    else()
        set(_safe_tweak)
        set(_safe_version ${_major}.${_minor}.${_patch})
    endif()
    c4_setg(PROJECT_VERSION_FULL ${version})
    c4_setg(PROJECT_VERSION ${_safe_version})
    c4_setg(PROJECT_VERSION_MAJOR ${_major})
    c4_setg(PROJECT_VERSION_MINOR ${_minor})
    c4_setg(PROJECT_VERSION_PATCH ${_patch})
    c4_setg(PROJECT_VERSION_TWEAK "${_safe_tweak}")
    c4_setg(PROJECT_VERSION_TWEAK_FULL "${_tweak}")
    c4_setg(${prefix}_VERSION_FULL ${version})
    c4_setg(${prefix}_VERSION ${_safe_version})
    c4_setg(${prefix}_VERSION_MAJOR ${_major})
    c4_setg(${prefix}_VERSION_MINOR ${_minor})
    c4_setg(${prefix}_VERSION_PATCH ${_patch})
    c4_setg(${prefix}_VERSION_TWEAK "${_safe_tweak}")
    c4_setg(${prefix}_VERSION_TWEAK_FULL "${_tweak}")
endmacro()


# Add targets for testing (dir=./test), benchmark (dir=./bm) and API (dir=./api).
# Call this macro towards the end of the project's main CMakeLists.txt.
# Experimental feature: docs.
function(c4_add_dev_targets)
    if(NOT CMAKE_CURRENT_LIST_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
        c4_err("this macro needs to be called on the project's main CMakeLists.txt file")
    endif()
    #
    if(${_c4_uprefix}BUILD_TESTS)
        if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/test")
            c4_dbg("adding tests: ${CMAKE_CURRENT_LIST_DIR}/test")
            enable_testing() # this must be done here (and not inside the
                             # test dir) so that the cmake-generated test
                             # targets are available at the top level
            add_subdirectory(test)
        endif()
    endif()
    #
    if(${_c4_uprefix}BUILD_BENCHMARKS)
        if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/bm")
            c4_dbg("adding benchmarks: ${CMAKE_CURRENT_LIST_DIR}/bm")
            add_subdirectory(bm)
        endif()
    endif()
    #
    if(${_c4_uprefix}BUILD_API)
        if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/api")
            c4_dbg("adding API: ${d}")
            add_subdirectory(api)
        endif()
    endif()
    #
    # FIXME
    c4_add_doxygen(doc DOXYFILE_IN ${_c4_project_dir}/Doxyfile.in
        PROJ c4core
        INPUT ${${_c4_uprefix}SRC_DIR}
        EXCLUDE ${${_c4_uprefix}EXT_DIR} ${${_c4_uprefix}SRC_DIR}/c4/ext
        STRIP_FROM_PATH ${${_c4_uprefix}SRC_DIR}
        STRIP_FROM_INC_PATH ${${_c4_uprefix}SRC_DIR}
        CLANG_DATABASE_PATH ${CMAKE_BINARY_DIR}
        )
    c4_add_doxygen(doc-full DOXYFILE_IN ${_c4_project_dir}/Doxyfile.full.in
        PROJ c4core
        INPUT ${${_c4_uprefix}SRC_DIR}
        EXCLUDE ${${_c4_uprefix}EXT_DIR} ${${_c4_uprefix}SRC_DIR}/c4/ext
        STRIP_FROM_PATH ${${_c4_uprefix}SRC_DIR}
        STRIP_FROM_INC_PATH ${${_c4_uprefix}SRC_DIR}
        CLANG_DATABASE_PATH ${CMAKE_BINARY_DIR}
        )
endfunction()


# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------

# utilities for compilation flags and defines

# flags enabled only on dev mode
macro(c4_optional_compile_flags_dev tag desc)
    _c4_handle_args(_ARGS ${ARGN}
        _ARGS0
        _ARGS1
        _ARGSN
            MSVC         # flags for Visual Studio compilers
            GCC          # flags for gcc compilers
            CLANG        # flags for clang compilers
            GCC_CLANG    # flags common to gcc and clang
        _DEPRECATE
    )
    if(${CMAKE_VERSION} VERSION_GREATER_EQUAL 3.22)
        cmake_policy(PUSH)
        cmake_policy(SET CMP0127 NEW)
    endif()
    cmake_dependent_option(${_c4_uprefix}${tag} "${desc}" ON ${_c4_uprefix}DEV OFF)
    if(${CMAKE_VERSION} VERSION_GREATER_EQUAL 3.22)
        cmake_policy(POP)
    endif()
    set(optname ${_c4_uprefix}${tag})
    if(${optname})
        c4_dbg("${optname} is enabled. Adding flags...")
        if(MSVC)
            set(flags ${_MSVC})
        elseif(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
            set(flags ${_GCC_CLANG};${_CLANG})
        elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            set(flags ${_GCC_CLANG};${_GCC})
        elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Intel")
            set(flags ${_ALL};${_GCC_CLANG};${_GCC})  # FIXME
        elseif(CMAKE_CXX_COMPILER_ID STREQUAL "IntelLLVM")
            set(flags ${_ALL};${_GCC_CLANG};${_CLANG})  # FIXME
        else()
            c4_err("unknown compiler")
        endif()
    else()
        c4_dbg("${optname} is disabled.")
    endif()
    if(flags)
        c4_log("${tag} flags [${desc}]: ${flags}")
        c4_setg(${_c4_uprefix}CXX_FLAGS_OPT "${${_c4_uprefix}CXX_FLAGS_OPT};${flags}")
    endif()
endmacro()


function(c4_target_compile_flags target)
    _c4_handle_args(_ARGS ${ARGN}
        _ARGS0
            PUBLIC
            PRIVATE
            INTERFACE
            AFTER        # this is the default
            BEFORE
        _ARGS1
        _ARGSN
            ALL          # flags for all compilers
            MSVC         # flags for Visual Studio compilers
            GCC          # flags for gcc compilers
            CLANG        # flags for clang compilers
            GCC_CLANG    # flags common to gcc and clang
        _DEPRECATE
    )
    if(MSVC)
        set(flags ${_ALL};${_MSVC})
    elseif(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
        set(flags ${_ALL};${_GCC_CLANG};${_CLANG})
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        set(flags ${_ALL};${_GCC_CLANG};${_GCC})
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Intel")
        set(flags ${_ALL};${_GCC_CLANG};${_GCC})  # FIXME
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "IntelLLVM")
        set(flags ${_ALL};${_GCC_CLANG};${_CLANG})  # FIXME
    else()
        c4_err("unknown compiler")
    endif()
    if(NOT flags)
        c4_dbg("no compile flags to be set")
        return()
    endif()
    if(_AFTER OR (NOT _BEFORE))
        set(mode)
        c4_log("${target}: adding compile flags AFTER: ${flags}")
    elseif(_BEFORE)
        set(mode BEFORE)
        c4_log("${target}: adding compile flags BEFORE: ${flags}")
    endif()
    if(_PUBLIC)
        target_compile_options(${target} ${mode} PUBLIC ${flags})
    elseif(_PRIVATE)
        target_compile_options(${target} ${mode} PRIVATE ${flags})
    elseif(_INTERFACE)
        target_compile_options(${target} ${mode} INTERFACE ${flags})
    else()
        c4_err("${target}: must have one of PUBLIC, PRIVATE or INTERFACE")
    endif()
endfunction()


function(c4_target_definitions target)
    _c4_handle_args(_ARGS ${ARGN}
        _ARGS0
            PUBLIC
            PRIVATE
            INTERFACE
        _ARGS1
        _ARGSN
            ALL          # defines for all compilers
            MSVC         # defines for Visual Studio compilers
            GCC          # defines for gcc compilers
            CLANG        # defines for clang compilers
            GCC_CLANG    # defines common to gcc and clang
        _DEPRECATE
    )
    if(MSVC)
        set(flags ${_ALL};${_MSVC})
    elseif(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
        set(flags ${_ALL};${_GCC_CLANG};${_CLANG})
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        set(flags ${_ALL};${_GCC_CLANG};${_GCC})
    else()
        c4_err("unknown compiler")
    endif()
    if(NOT flags)
        c4_dbg("no compile flags to be set")
        return()
    endif()
    if(_AFTER OR (NOT _BEFORE))
        set(mode)
        c4_log("${target}: adding definitions AFTER: ${flags}")
    elseif(_BEFORE)
        set(mode BEFORE)
        c4_log("${target}: adding definitions BEFORE: ${flags}")
    endif()
    if(_PUBLIC)
        target_compile_definitions(${target} ${mode} PUBLIC ${flags})
    elseif(_PRIVATE)
        target_compile_definitions(${target} ${mode} PRIVATE ${flags})
    elseif(_INTERFACE)
        target_compile_definitions(${target} ${mode} INTERFACE ${flags})
    else()
        c4_err("${target}: must have one of PUBLIC, PRIVATE or INTERFACE")
    endif()
endfunction()


function(c4_target_remove_compile_flags target)
    _c4_handle_args(_ARGS ${ARGN}
        _ARGS0
            PUBLIC       # remove only from public compile options
            INTERFACE    # remove only from interface compile options
        _ARGS1
        _ARGSN
            MSVC         # flags for Visual Studio compilers
            GCC          # flags for gcc compilers
            CLANG        # flags for clang compilers
            GCC_CLANG    # flags common to gcc and clang
        _DEPRECATE
    )
    if(MSVC)
        set(flags ${_MSVC})
    elseif(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
        set(flags ${_GCC_CLANG};${_CLANG})
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        set(flags ${_GCC_CLANG};${_GCC})
    else()
        c4_err("unknown compiler")
    endif()
    if(NOT flags)
        return()
    endif()
    if(_PUBLIC OR (NOT _INTERFACE))
        get_target_property(co ${target} COMPILE_OPTIONS)
        if(co)
            _c4_remove_entries_from_list("${flags}" co)
            set_target_properties(${target} PROPERTIES COMPILE_OPTIONS "${co}")
        endif()
    endif()
    if(_INTERFACE OR (NOT _PUBLIC))
        get_target_property(ico ${target} INTERFACE_COMPILE_OPTIONS)
        if(ico)
            _c4_remove_entries_from_list("${flags}" ico)
            set_target_properties(${target} PROPERTIES INTERFACE_COMPILE_OPTIONS "${ico}")
        endif()
    endif()
endfunction()


function(_c4_remove_entries_from_list entries_to_remove list)
    set(str ${${list}})
    string(REPLACE ";" "==?==" str "${str}")
    foreach(entry ${entries_to_remove})
        string(REPLACE "${entry}" "" str "${str}")
    endforeach()
    string(REPLACE "==?==" ";" str "${str}")
    string(REPLACE ";;" ";" str "${str}")
    set(${list} "${str}" PARENT_SCOPE)
endfunction()



# pedantic flags...
# default pedantic flags taken from:
# https://github.com/lefticus/cpp_starter_project/blob/master/cmake/CompilerWarnings.cmake
set(_C4_PEDANTIC_FLAGS_MSVC
    /W4 # Baseline reasonable warnings
    /w14242 # 'identifier': conversion from 'type1' to 'type1', possible loss of data
    /w14254 # 'operator': conversion from 'type1:field_bits' to 'type2:field_bits', possible loss of data
    /w14263 # 'function': member function does not override any base class virtual member function
    /w14265 # 'classname': class has virtual functions, but destructor is not virtual instances of this class may not
            # be destructed correctly
    /w14287 # 'operator': unsigned/negative constant mismatch
    /we4289 # nonstandard extension used: 'variable': loop control variable declared in the for-loop is used outside
            # the for-loop scope
    /w14296 # 'operator': expression is always 'boolean_value'
    /w14311 # 'variable': pointer truncation from 'type1' to 'type2'
    /w14545 # expression before comma evaluates to a function which is missing an argument list
    /w14546 # function call before comma missing argument list
    /w14547 # 'operator': operator before comma has no effect; expected operator with side-effect
    /w14549 # 'operator': operator before comma has no effect; did you intend 'operator'?
    /w14555 # expression has no effect; expected expression with side- effect
    /w14619 # pragma warning: there is no warning number 'number'
    /w14640 # Enable warning on thread un-safe static member initialization
    /w14826 # Conversion from 'type1' to 'type_2' is sign-extended. This may cause unexpected runtime behavior.
    /w14905 # wide string literal cast to 'LPSTR'
    /w14906 # string literal cast to 'LPWSTR'
    /w14928 # illegal copy-initialization; more than one user-defined conversion has been implicitly applied
    $<$<VERSION_GREATER:${MSVC_VERSION},1900>:/permissive-> # standards conformance mode for MSVC compiler (only vs2017+)
    )

set(_C4_PEDANTIC_FLAGS_COMMON
    -Wall
    -Wextra
    -pedantic
    -Wpedantic
    -Wshadow # warn the user if a variable declaration shadows one from a parent context
    -Wnon-virtual-dtor # warn the user if a class with virtual functions has a non-virtual destructor. This helps
                       # catch hard to track down memory errors
    -Wold-style-cast # warn for c-style casts
    -Wcast-align # warn for potential performance problem casts
    -Wcast-qual
    -Wunused # warn on anything being unused
    -Wunused-function
    -Wunused-variable
    -Woverloaded-virtual # warn if you overload (not override) a virtual function
    -Wpedantic # warn if non-standard C++ is used
    -Wconversion # warn on type conversions that may lose data
    -Wsign-conversion # warn on sign conversions
    -Wdouble-promotion # warn if float is implicitly promoted to double
    -Wfloat-equal # warn if comparing floats
    -Wempty-body
    -Wformat=2 # warn on security issues around functions that format output (ie printf)
    -Wformat-security
    -Wundef
    # only available for C files:
    $<$<COMPILE_LANGUAGE:C>:-Wbad-function-cast>
    $<$<COMPILE_LANGUAGE:C>:-Wmissing-prototypes>
    $<$<COMPILE_LANGUAGE:C>:-Wold-style-definition>
    $<$<COMPILE_LANGUAGE:C>:-Wstrict-prototypes>
    $<$<COMPILE_LANGUAGE:C>:-Wpointer-sign>
    )

set(_C4_PEDANTIC_FLAGS_CLANG ${_C4_PEDANTIC_FLAGS_COMMON})
set(_C4_PEDANTIC_FLAGS_GCC ${_C4_PEDANTIC_FLAGS_COMMON}
    -Wlogical-op # logical operations are used where bitwise were probably wanted
    -Wuseless-cast # cast to the same type
    )

if(CMAKE_CXX_COMPILER_ID STREQUAL "")
    message(FATAL_ERROR "project() must be called before including this file")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL GNU)
    if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 6.0)
        list(APPEND _C4_PEDANTIC_FLAGS_GCC
            -Wunused-const-variable
            -Wignored-attributes
            -Wnull-dereference # warn if a null dereference is detected
            -Wmisleading-indentation # where indentation implies blocks where blocks do not exist
            -Wduplicated-cond # where if-else chain has duplicated conditions
            $<$<COMPILE_LANGUAGE:C>:-Wabsolute-value>
        )
    endif()
    if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 7.0)
        list(APPEND _C4_PEDANTIC_FLAGS_GCC
            -Wduplicated-branches # where if-else branches have duplicated code
        )
    endif()
    if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 8.0)
        list(APPEND _C4_PEDANTIC_FLAGS_GCC
        )
    endif()
    if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 9.0)
        list(APPEND _C4_PEDANTIC_FLAGS_GCC
            -Waddress-of-packed-member
        )
    endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL Clang)
    if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 6.0)
        list(APPEND _C4_PEDANTIC_FLAGS_CLANG
            -Wself-assign
            -Wparentheses-equality
            -Wgnu-variable-sized-type-not-at-end
            -Winconsistent-missing-override
            -Wbitfield-constant-conversion
            -Wsometimes-uninitialized
            -Wextern-initializer
            -Wmissing-braces
        )
    endif()
    if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 11.0)
        list(APPEND _C4_PEDANTIC_FLAGS_CLANG
            -Wexcess-initializers
        )
    endif()
endif()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

function(c4_pack_project)
    # if this is the top-level project... pack it.
    if(CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
        c4_log("packing the project: ${ARGN}")
        c4_set_default_pack_properties(${ARGN})
        include(CPack)
    endif()
endfunction()


# [WIP] set convenient defaults for the properties used by CPack
function(c4_set_default_pack_properties)
    _c4_handle_args(_ARGS ${ARGN}
      _ARGS0  # zero-value macro arguments
      _ARGS1  # one-value macro arguments
        TYPE     # one of LIBRARY, EXECUTABLE
      _ARGSN  # multi-value macro arguments
    )
    set(pd "${PROJECT_SOURCE_DIR}")
    _c4_handle_arg(TYPE EXECUTABLE)  # default to EXECUTABLE
    #
    _c4_get_platform_tag(platform_tag)
    if("${_TYPE}" STREQUAL "LIBRARY")
        if(BUILD_SHARED_LIBS)
            set(build_tag "-shared")
        else()
            set(build_tag "-static")
        endif()
        get_property(multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
        if(multi_config)
            # doesn't work because generators are not evaluated: set(build_tag "${build_tag}-$<CONFIG>")
            # doesn't work because generators are not evaluated: set(build_tag "${build_tag}$<$<CONFIG:Debug>:-Debug>$<$<CONFIG:MinSizeRel>:-MinSizeRel>$<$<CONFIG:Release>:-Release>$<$<CONFIG:RelWithDebInfo>:-RelWithDebInfo>")
            # see also https://stackoverflow.com/questions/44153730/how-to-change-cpack-package-file-name-based-on-configuration
            if(CMAKE_BUILD_TYPE)  # in the off-chance it was explicitly set
                set(build_tag "${build_tag}-${CMAKE_BUILD_TYPE}")
            endif()
        else()
            set(build_tag "${build_tag}-${CMAKE_BUILD_TYPE}")
        endif()
    elseif("${_TYPE}" STREQUAL "EXECUTABLE")
        set(build_tag)
    elseif()
        c4_err("unknown TYPE: ${_TYPE}")
    endif()
    #
    c4_setg(CPACK_VERBATIM_VARIABLES true)
    c4_setg(CPACK_PACKAGE_VENDOR "${${_c4_prefix}_HOMEPAGE_URL}")
    c4_setg(CPACK_PACKAGE_CONTACT "${${_c4_prefix}_AUTHOR}")
    c4_setg(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${${_c4_prefix}_DESCRIPTION}")
    if(EXISTS "${pd}/README.md")
        c4_setg(CPACK_PACKAGE_DESCRIPTION_FILE "${pd}/README.md")
        c4_setg(CPACK_PACKAGE_DESCRIPTION_README "${pd}/README.md")
        c4_setg(CPACK_PACKAGE_DESCRIPTION_WELCOME "${pd}/README.md")
    elseif(EXISTS "${pd}/README.txt")
        c4_setg(CPACK_PACKAGE_DESCRIPTION_FILE "${pd}/README.txt")
        c4_setg(CPACK_PACKAGE_DESCRIPTION_README "${pd}/README.txt")
        c4_setg(CPACK_PACKAGE_DESCRIPTION_WELCOME "${pd}/README.txt")
    endif()
    if(EXISTS "${pd}/LICENSE.md")
        c4_setg(CPACK_RESOURCE_FILE_LICENSE "${pd}/LICENSE.md")
    elseif(EXISTS "${pd}/LICENSE.txt")
        c4_setg(CPACK_RESOURCE_FILE_LICENSE "${pd}/LICENSE.txt")
    endif()
    c4_proj_get_version("${pd}" version_tag full major minor patch tweak)
    c4_setg(CPACK_PACKAGE_VERSION "${full}")
    c4_setg(CPACK_PACKAGE_VERSION_MAJOR "${major}")
    c4_setg(CPACK_PACKAGE_VERSION_MINOR "${minor}")
    c4_setg(CPACK_PACKAGE_VERSION_PATCH "${patch}")
    c4_setg(CPACK_PACKAGE_VERSION_TWEAK "${tweak}")
    c4_setg(CPACK_PACKAGE_INSTALL_DIRECTORY "${_c4_prefix}-${version_tag}")
    c4_setg(CPACK_PACKAGE_FILE_NAME "${_c4_prefix}-${version_tag}-${platform_tag}${build_tag}")
    if(WIN32 AND NOT UNIX)
        # There is a bug in NSI that does not handle full UNIX paths properly.
        # Make sure there is at least one set of four backlashes.
        #c4_setg(CPACK_PACKAGE_ICON "${CMake_SOURCE_DIR}/Utilities/Release\\\\InstallIcon.bmp")
        #c4_setg(CPACK_NSIS_INSTALLED_ICON_NAME "bin\\\\MyExecutable.exe")
        c4_setg(CPACK_NSIS_DISPLAY_NAME "${_c4_prefix} ${version_tag}")
        c4_setg(CPACK_NSIS_HELP_LINK "${${_c4_prefix}_HOMEPAGE_URL}")
        c4_setg(CPACK_NSIS_URL_INFO_ABOUT "${${_c4_prefix}_HOMEPAGE_URL}")
        c4_setg(CPACK_NSIS_CONTACT "${${_c4_prefix}_AUTHOR}")
        c4_setg(CPACK_NSIS_MODIFY_PATH ON)
    else()
        #c4_setg(CPACK_STRIP_FILES "bin/MyExecutable")
        #c4_setg(CPACK_SOURCE_STRIP_FILES "")
        c4_setg(CPACK_DEBIAN_PACKAGE_MAINTAINER "${${_c4_prefix}_AUTHOR}")
    endif()
    #c4_setg(CPACK_PACKAGE_EXECUTABLES "MyExecutable" "My Executable")
endfunction()


function(_c4_get_platform_tag tag_)
    if(WIN32 AND NOT UNIX)
        set(tag win)
    elseif(APPLE)
        set(tag apple)
    elseif(UNIX)
        set(tag unix)
    else()
        set(tag ${CMAKE_SYSTEM_NAME})
    endif()
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)  # 64 bits
        set(tag ${tag}64)
    elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)  # 32 bits
        set(tag ${tag}32)
    else()
        c4_err("not implemented")
    endif()
    set(${tag_} ${tag} PARENT_SCOPE)
endfunction()


function(_c4_extract_version_tag tag_)
    # git describe --tags  <commit-id> for unannotated tags
    # git describe --contains <commit>
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# set project-wide property
function(c4_set_proj_prop prop value)
    c4_dbg("set ${prop}=${value}")
    set(C4PROJ_${_c4_prefix}_${prop} ${value})
endfunction()

# set project-wide property
function(c4_get_proj_prop prop var)
    c4_dbg("get ${prop}=${C4PROJ_${_c4_prefix}_${prop}}")
    set(${var} ${C4PROJ_${_c4_prefix}_${prop}} PARENT_SCOPE)
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# set target-wide c4 property
function(c4_set_target_prop target prop value)
    _c4_set_tgt_prop(${target} C4_TGT_${prop} "${value}")
endfunction()
function(c4_append_target_prop target prop value)
    _c4_append_tgt_prop(${target} C4_TGT_${prop} "${value}")
endfunction()

# get target-wide c4 property
function(c4_get_target_prop target prop var)
    _c4_get_tgt_prop(val ${target} C4_TGT_${prop})
    set(${var} ${val} PARENT_SCOPE)
endfunction()


# get target-wide property
function(_c4_get_tgt_prop out tgt prop)
    get_target_property(target_type ${target} TYPE)
    if(target_type STREQUAL "INTERFACE_LIBRARY")
        get_property(val GLOBAL PROPERTY C4_TGT_${tgt}_${prop})
    else()
        get_target_property(val ${tgt} ${prop})
    endif()
    c4_dbg("target ${tgt}: get ${prop}=${val}")
    set(${out} "${val}" PARENT_SCOPE)
endfunction()

# set target-wide property
function(_c4_set_tgt_prop tgt prop propval)
    c4_dbg("target ${tgt}: set ${prop}=${propval}")
    get_target_property(target_type ${target} TYPE)
    if(target_type STREQUAL "INTERFACE_LIBRARY")
        set_property(GLOBAL PROPERTY C4_TGT_${tgt}_${prop} "${propval}")
    else()
        set_target_properties(${tgt} PROPERTIES ${prop} "${propval}")
    endif()
endfunction()
function(_c4_append_tgt_prop tgt prop propval)
    c4_dbg("target ${tgt}: appending ${prop}=${propval}")
    _c4_get_tgt_prop(curr ${tgt} ${prop})
    if(curr)
        list(APPEND curr "${propval}")
    else()
        set(curr "${propval}")
    endif()
    _c4_set_tgt_prop(${tgt} ${prop} "${curr}")
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

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

function(c4_proj_get_version dir tag_o full_o major_o minor_o patch_o tweak_o)
    if("${dir}" STREQUAL "")
        set(dir ${CMAKE_CURRENT_LIST_DIR})
    endif()
    find_program(GIT git REQUIRED)
    function(_c4pgv_get_cmd outputvar)
        execute_process(COMMAND ${ARGN}
            WORKING_DIRECTORY ${dir}
            ERROR_VARIABLE error
            ERROR_STRIP_TRAILING_WHITESPACE
            OUTPUT_VARIABLE output
            OUTPUT_STRIP_TRAILING_WHITESPACE)
        c4_dbg("output of ${ARGN}: ${outputvar}=${output} [@${dir}]")
        set(${outputvar} ${output} PARENT_SCOPE)
    endfunction()
    # do we have any tags yet?
    _c4pgv_get_cmd(head_desc ${GIT} describe HEAD)
    _c4pgv_get_cmd(branch ${GIT} rev-parse --abbrev-ref HEAD)
    if(NOT head_desc)
        c4_dbg("the repo does not have any tags yet")
        _c4pgv_get_cmd(commit_hash ${GIT} rev-parse --short HEAD)
        set(otag "${commit_hash}-${branch}")
    else()
        c4_dbg("there are tags!")
        # is the current commit tagged?
        _c4pgv_get_cmd(commit_hash_full ${GIT} rev-parse HEAD)
        _c4pgv_get_cmd(commit_desc ${GIT} describe --exact-match ${commit_hash_full})
        if(commit_desc)
            c4_dbg("current commit is tagged")
            # is the tag a version tag?
            _c4_parse_version_tag(${commit_desc} is_version major minor patch tweak more)
            if(is_version)
                c4_dbg("current commit's tag is a version tag")
                # is the tag the current version tag?
                if("${is_version}" VERSION_EQUAL "${${_c4_prefix}_VERSION_FULL}")
                    c4_dbg("this is the official version commit")
                else()
                    c4_dbg("this is a different version")
                endif()
                set(otag "${commit_desc}")
            else()
                c4_dbg("this is a non-version tag")
                set(otag "${commit_desc}-${branch}")
            endif()
        else(commit_desc)
            # is the latest tag in the head_desc a version tag?
            string(REGEX REPLACE "(.*)-[0-9]+-[0-9a-f]+" "\\1" latest_tag "${head_desc}")
            c4_dbg("current commit is NOT tagged. latest tag=${latest_tag}")
            _c4_parse_version_tag(${latest_tag} latest_tag_is_a_version major minor patch tweak more)
            if(latest_tag_is_a_version)
                c4_dbg("latest tag is a version. stick to the head description")
                set(otag "${head_desc}-${branch}")
                set(full "${latest_tag_is_a_version}")
            else()
                c4_dbg("latest tag is NOT a version. Use the current project version from cmake + the output of git describe")
                set(otag "v${full}-${head_desc}-${branch}")
                set(full "${${_c4_prefix}_VERSION_FULL}")
                set(major "${${_c4_prefix}_VERSION_MAJOR}")
                set(minor "${${_c4_prefix}_VERSION_MINOR}")
                set(patch "${${_c4_prefix}_VERSION_PATCH}")
                set(tweak "${${_c4_prefix}_VERSION_TWEAK}")
            endif()
        endif(commit_desc)
    endif(NOT head_desc)
    c4_log("cpack tag: ${otag}")
    set(${tag_o}   "${otag}"  PARENT_SCOPE)
    set(${full_o}  "${full}"  PARENT_SCOPE)
    set(${major_o} "${major}" PARENT_SCOPE)
    set(${minor_o} "${minor}" PARENT_SCOPE)
    set(${patch_o} "${patch}" PARENT_SCOPE)
    set(${tweak_o} "${tweak}" PARENT_SCOPE)
    # also: dirty index?
    #   https://stackoverflow.com/questions/2657935/checking-for-a-dirty-index-or-untracked-files-with-git
endfunction()


function(_c4_parse_version_tag tag is_version major minor patch tweak more)
    # does the tag match a four-part version?
    string(REGEX MATCH "v?([0-9]+)([\._][0-9]+)([\._][0-9]+)([\._][0-9]+)(.*)" match "${tag}")
    function(_triml arg out) # trim the leading [\._] from the left
        if("${arg}" STREQUAL "")
            set(${out} "" PARENT_SCOPE)
        else()
            string(REGEX REPLACE "[\._](.*)" "\\1" ret "${arg}")
            set("${out}" "${ret}" PARENT_SCOPE)
        endif()
    endfunction()
    if(match)
        set(${is_version} ${tag} PARENT_SCOPE)
        _triml("${CMAKE_MATCH_1}" major_v)
        _triml("${CMAKE_MATCH_2}" minor_v)
        _triml("${CMAKE_MATCH_3}" patch_v)
        _triml("${CMAKE_MATCH_4}" tweak_v)
        _triml("${CMAKE_MATCH_5}" more_v)
    else()
        # does the tag match a three-part version?
        string(REGEX MATCH "v?([0-9]+)([\._][0-9]+)([\._][0-9]+)(.*)" match "${tag}")
        if(match)
            set(${is_version} ${tag} PARENT_SCOPE)
            _triml("${CMAKE_MATCH_1}" major_v)
            _triml("${CMAKE_MATCH_2}" minor_v)
            _triml("${CMAKE_MATCH_3}" patch_v)
            _triml("${CMAKE_MATCH_4}" more_v)
        else()
            # does the tag match a two-part version?
            string(REGEX MATCH "v?([0-9]+)([\._][0-9]+)(.*)" match "${tag}")
            if(match)
                set(${is_version} ${tag} PARENT_SCOPE)
                _triml("${CMAKE_MATCH_1}" major_v)
                _triml("${CMAKE_MATCH_2}" minor_v)
                _triml("${CMAKE_MATCH_3}" more_v)
            else()
                # not a version!
                set(${is_version} FALSE PARENT_SCOPE)
            endif()
        endif()
    endif()
    set(${major} "${major_v}" PARENT_SCOPE)
    set(${minor} "${minor_v}" PARENT_SCOPE)
    set(${patch} "${patch_v}" PARENT_SCOPE)
    set(${tweak} "${tweak_v}" PARENT_SCOPE)
    set(${more} "${more_v}" PARENT_SCOPE)
endfunction()


#function(testvtag)
#    set(err FALSE)
#    function(cmp value expected)
#        if(NOT ("${${value}}" STREQUAL "${expected}"))
#            c4_log("${tag}: error: expected ${value}=='${expected}': '${${value}}'=='${expected}'")
#            set(err TRUE PARENT_SCOPE)
#        else()
#            c4_log("${tag}: ok: expected ${value}=='${expected}': '${${value}}'=='${expected}'")
#        endif()
#    endfunction()
#    function(verify tag is_version_e major_e minor_e patch_e tweak_e more_e)
#        _c4_parse_version_tag(${tag} is_version major minor patch tweak more)
#        cmp(is_version ${is_version_e})
#        cmp(major "${major_e}")
#        cmp(minor "${minor_e}")
#        cmp(patch "${patch_e}")
#        cmp(tweak "${tweak_e}")
#        cmp(more "${more_e}")
#        set(err ${err} PARENT_SCOPE)
#    endfunction()
#    verify(v12.34.567.89-rcfoo TRUE 12 34 567 89 -rcfoo)
#    verify(v12_34_567_89-rcfoo TRUE 12 34 567 89 -rcfoo)
#    verify(v12.34.567.89       TRUE 12 34 567 89 "")
#    verify(v12_34_567_89       TRUE 12 34 567 89 "")
#    verify(v12.34.567-rcfoo    TRUE 12 34 567 "" -rcfoo)
#    verify(v12_34_567-rcfoo    TRUE 12 34 567 "" -rcfoo)
#    verify(v12.34.567          TRUE 12 34 567 "" "")
#    verify(v12_34_567          TRUE 12 34 567 "" "")
#    verify(v12_34              TRUE 12 34 ""  "" "")
#    verify(v12.34              TRUE 12 34 ""  "" "")
#    if(err)
#        c4_err("test failed")
#    endif()
#endfunction()
#testvtag()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------


macro(_c4_handle_cxx_standard_args)
    # EXTENSIONS:
    # enable compiler extensions eg, prefer gnu++11 to c++11
    if(EXTENSIONS IN_LIST ARGN)
        set(_EXTENSIONS ON)
    else()
        c4_get_from_first_of(_EXTENSIONS
            ENV
            DEFAULT OFF
            VARS ${_c4_uprefix}CXX_EXTENSIONS C4_CXX_EXTENSIONS CMAKE_CXX_EXTENSIONS)
    endif()
    #
    # OPTIONAL
    if(OPTIONAL IN_LIST ARGN)
        set(_REQUIRED OFF)
    else()
        c4_get_from_first_of(_REQUIRED
            ENV
            DEFAULT ON
            VARS ${_c4_uprefix}CXX_STANDARD_REQUIRED C4_CXX_STANDARD_REQUIRED CMAKE_CXX_STANDARD_REQUIRED)
    endif()
endmacro()


# set the global cxx standard for the project.
#
# examples:
# c4_set_cxx(latest) # find the latest standard supported by the compiler, and use that
# c4_set_cxx(11) # required, no extensions (eg c++11)
# c4_set_cxx(14) # required, no extensions (eg c++14)
# c4_set_cxx(11 EXTENSIONS) # opt-in to extensions (eg, gnu++11)
# c4_set_cxx(14 EXTENSIONS) # opt-in to extensions (eg, gnu++14)
# c4_set_cxx(11 OPTIONAL) # not REQUIRED. no extensions
# c4_set_cxx(11 OPTIONAL EXTENSIONS) # not REQUIRED. with extensions.
macro(c4_set_cxx standard)
    _c4_handle_cxx_standard_args(${ARGN})
    if(NOT DEFINED CMAKE_CXX_STANDARD)
        c4_log("setting C++ standard: ${standard}")
        c4_setg(CMAKE_CXX_STANDARD ${standard})
    endif()
    if(NOT DEFINED CMAKE_CXX_STANDARD_REQUIRED)
        c4_log("setting C++ standard required: ${_REQUIRED}")
        c4_setg(CMAKE_CXX_STANDARD_REQUIRED ${_REQUIRED})
    endif()
    if(NOT DEFINED CMAKE_CXX_STANDARD_REQUIRED)
        c4_log("setting C++ standard extensions: ${_EXTENSIONS}")
        c4_setg(CMAKE_CXX_EXTENSIONS ${_EXTENSIONS})
    endif()
endmacro()


# set the cxx standard for a target.
#
# examples:
# c4_target_set_cxx(target latest) # find the latest standard supported by the compiler, and use that
# c4_target_set_cxx(target 11) # required, no extensions (eg c++11)
# c4_target_set_cxx(target 14) # required, no extensions (eg c++14)
# c4_target_set_cxx(target 11 EXTENSIONS) # opt-in to extensions (eg, gnu++11)
# c4_target_set_cxx(target 14 EXTENSIONS) # opt-in to extensions (eg, gnu++14)
# c4_target_set_cxx(target 11 OPTIONAL) # not REQUIRED. no extensions
# c4_target_set_cxx(target 11 OPTIONAL EXTENSIONS)
function(c4_target_set_cxx target standard)
    c4_dbg("setting C++ standard for target ${target}: ${standard}")
    _c4_handle_cxx_standard_args(${ARGN})
    set_target_properties(${target} PROPERTIES
        CXX_STANDARD ${standard}
        CXX_STANDARD_REQUIRED ${_REQUIRED}
        CXX_EXTENSIONS ${_EXTENSIONS})
    target_compile_features(${target} PUBLIC cxx_std_${standard})
endfunction()


# set the cxx standard for a target based on the global project settings
function(c4_target_inherit_cxx_standard target)
    c4_dbg("inheriting C++ standard for target ${target}: ${CMAKE_CXX_STANDARD}")
    set_target_properties(${target} PROPERTIES
        CXX_STANDARD "${CMAKE_CXX_STANDARD}"
        CXX_STANDARD_REQUIRED "${CMAKE_CXX_STANDARD_REQUIRED}"
        CXX_EXTENSIONS "${CMAKE_CXX_EXTENSIONS}")
    target_compile_features(${target} PUBLIC cxx_std_${CMAKE_CXX_STANDARD})
endfunction()


function(_c4_find_latest_supported_cxx_standard out)
    if(NOT c4_latest_supported_cxx_standard)
        include(CheckCXXCompilerFlag)
        # make sure CMAKE_CXX_FLAGS is clean here
        # see https://cmake.org/cmake/help/v3.16/module/CheckCXXCompilerFlag.html
        # Note: since this is a function, we don't need to reset CMAKE_CXX_FLAGS
        # back to its previous value
        set(CMAKE_CXX_FLAGS)
        set(standard 11)  # default to C++11 if everything fails
        foreach(s ${C4_CXX_STANDARDS})
            if(MSVC)
                set(flag /std:c++${s})
            else()
                # assume GNU-style compiler
                set(flag -std=c++${s})
            endif()
            c4_log("checking CXX standard: C++${s} flag=${flag}")
            check_cxx_compiler_flag(${flag} has${s})
            if(has${s})
                c4_log("checking CXX standard: C++${s} is supported! flag=${flag}")
                set(standard ${s})
                break()
            else()
                c4_log("checking CXX standard: C++${s}: no support for flag=${flag} no")
            endif()
        endforeach()
        set(c4_latest_supported_cxx_standard ${standard} CACHE INTERNAL "")
    endif()
    set(${out} ${c4_latest_supported_cxx_standard} PARENT_SCOPE)
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# examples:
#
# # require subproject c4core, as a subdirectory. c4core will be used
# # as a separate library
# c4_require_subproject(c4core SUBDIRECTORY ${C4OPT_EXT_DIR}/c4core)
#
# # require subproject c4core, as a remote proj
# c4_require_subproject(c4core REMOTE
#     IMPORTED_DIR c4core_download_dir  # this variable will contain where c4core was downloaded to
#     GIT_REPOSITORY https://github.com/biojppm/c4core
#     GIT_TAG master
#     )
function(c4_require_subproject subproj)
    _c4_handle_args(_ARGS ${ARGN}
        _ARGS0
            INCORPORATE
            EXCLUDE_FROM_ALL
        _ARGS1
            SUBDIRECTORY   # the subproject is located in the given directory name and
                           # will be added via add_subdirectory()
            IMPORTED_DIR   # [output] path to the location where the proj was
                           # found or downloaded to (for REMOTE projects)
        _ARGSN
            REMOTE         # the subproject is located in a remote repo/url
                           # and will be added via c4_import_remote_proj(),
                           # forwarding all the arguments in here.
            OVERRIDE       # a list of variable name+value pairs
                           # these variables will be set with c4_override()
                           # before calling add_subdirectory()
            SET_FOLDER_TARGETS   # Set the folder of the given targets using
                                 # c4_set_folder_remote_project_targets().
                                 # The first expected argument is the folder,
                                 # and the remaining arguments are the targets
                                 # which we want to set the folder.
        _DEPRECATE
            INTERFACE
    )
    #
    if((NOT _REMOTE) AND (NOT _SUBDIRECTORY))
        c4_err("a project must be imported either in REMOTE or SUBDIRECTORY mode")
    endif()
    #
    list(APPEND _${_c4_uprefix}_deps ${subproj})
    c4_setg(_${_c4_uprefix}_deps ${_${_c4_uprefix}_deps})
    c4_dbg("-----------------------------------------------")
    c4_dbg("requires subproject ${subproj}!")
    if(_INCORPORATE)
        c4_dbg("requires subproject ${subproj} in INCORPORATE mode!")
        c4_dbg_var(${_c4_root_uproj}_STANDALONE)
        if(${_c4_root_uproj}_STANDALONE)
            c4_dbg("${_c4_root_uproj} is STANDALONE: honoring INCORPORATE mode...")
        else()
            c4_dbg("${_c4_root_uproj} is not STANDALONE: ignoring INCORPORATE mode...")
            set(_INCORPORATE OFF)
        endif()
    endif()
    #
    _c4_get_subproject_property(${subproj} AVAILABLE _available)
    if(_available)
        c4_dbg("required subproject ${subproj} was already imported:")
        c4_dbg_subproject(${subproj})
        # TODO check version compatibility
    else() #elseif(NOT _${subproj}_available)
        c4_dbg("required subproject ${subproj} is unknown. Importing...")
        # forward c4 compile flags
        string(TOUPPER ${subproj} usubproj)
        c4_setg(${usubproj}_CXX_FLAGS_FWD "${${_c4_uprefix}CXX_FLAGS}")
        c4_setg(${usubproj}_CXX_FLAGS_OPT_FWD "${${_c4_uprefix}CXX_FLAGS_OPT}")
        c4_setg(${usubproj}_CXX_LINKER_FLAGS_FWD "${${_c4_uprefix}CXX_LINKER_FLAGS}")
        # root dir
        set(_r ${CMAKE_CURRENT_BINARY_DIR}/subprojects/${subproj})
        # forward import settings
        set(_more_options OVERRIDE ${_OVERRIDE})
        if(_EXCLUDE_FROM_ALL)
            list(APPEND _more_options EXCLUDE_FROM_ALL)
        endif()
        # do it!
        if(_REMOTE)
            c4_log("importing subproject ${subproj} (REMOTE)... ${_REMOTE}")
            _c4_mark_subproject_imported(${subproj} ${_r}/src ${_r}/build ${_INCORPORATE})
            c4_import_remote_proj(${subproj} ${_r} REMOTE ${_REMOTE} ${_more_options})
            _c4_get_subproject_property(${subproj} SRC_DIR _srcdir)
            c4_log("finished importing subproject ${subproj} (REMOTE, SRC_DIR=${_srcdir}).")
            if(_IMPORTED_DIR)
                set(${_IMPORTED_DIR} ${_srcdir} PARENT_SCOPE)
            endif()
        elseif(_SUBDIRECTORY)
            c4_log("importing subproject ${subproj} (SUBDIRECTORY)... ${_SUBDIRECTORY}")
            _c4_mark_subproject_imported(${subproj} ${_SUBDIRECTORY} ${_r}/build ${_INCORPORATE})
            c4_add_subproj(${subproj} ${_SUBDIRECTORY} ${_r}/build ${_more_options})
            set(_srcdir ${_SUBDIRECTORY})
            c4_dbg("finished importing subproject ${subproj} (SUBDIRECTORY=${_SUBDIRECTORY}).")
        else()
            c4_err("subproject type must be either REMOTE or SUBDIRECTORY")
        endif()
    endif()
    #
    if(_SET_FOLDER_TARGETS)
        c4_set_folder_remote_project_targets(${_SET_FOLDER_TARGETS})
    endif()
endfunction(c4_require_subproject)


function(c4_add_subproj proj dir bindir)
    _c4_handle_args(_ARGS ${ARGN}
        _ARGS0
            EXCLUDE_FROM_ALL # forward to add_subdirectory()
        _ARGS1
        _ARGSN
            OVERRIDE   # a list of variable name+value pairs
                       # these variables will be set with c4_override()
                       # before calling add_subdirectory()
    )
    # push the subproj into the current path
    set(prev_subproject ${_c4_curr_subproject})
    set(prev_path ${_c4_curr_path})
    set(_c4_curr_subproject ${proj})
    string(REGEX MATCH ".*/${proj}\$" pos "${_c4_curr_path}")
    if(pos EQUAL -1)
        string(REGEX MATCH "^${proj}\$" pos "${_c4_curr_path}")
        if(pos EQUAL -1)
            set(_c4_curr_path ${_c4_curr_path}/${proj})
        endif()
    endif()
    #
    while(_OVERRIDE)
        list(POP_FRONT _OVERRIDE varname)
        list(POP_FRONT _OVERRIDE varvalue)
        c4_override(${varname} ${varvalue})
    endwhile()
    #
    if(_EXCLUDE_FROM_ALL)
        set(excl EXCLUDE_FROM_ALL)
    endif()
    #
    c4_dbg("adding subproj: ${prev_subproject}->${_c4_curr_subproject}. path=${_c4_curr_path}")
    add_subdirectory(${dir} ${bindir} ${excl})
    # pop the subproj from the current path
    set(_c4_curr_subproject ${prev_subproject})
    set(_c4_curr_path ${prev_path})
endfunction()


function(_c4_mark_subproject_imported subproject_name subproject_src_dir subproject_bin_dir incorporate)
    c4_dbg("marking subproject imported: ${subproject_name} (imported by ${_c4_prefix}). src=${subproject_src_dir}")
    _c4_append_subproject_property(${_c4_prefix} DEPENDENCIES ${subproject_name})
    _c4_get_folder(folder ${_c4_prefix} ${subproject_name})
    _c4_set_subproject_property(${subproject_name} AVAILABLE ON)
    _c4_set_subproject_property(${subproject_name} IMPORTER "${_c4_prefix}")
    _c4_set_subproject_property(${subproject_name} SRC_DIR "${subproject_src_dir}")
    _c4_set_subproject_property(${subproject_name} BIN_DIR "${subproject_bin_dir}")
    _c4_set_subproject_property(${subproject_name} FOLDER "${folder}")
    _c4_set_subproject_property(${subproject_name} INCORPORATE "${incorporate}")
endfunction()


function(_c4_get_subproject_property subproject property var)
    get_property(v GLOBAL PROPERTY _c4_subproject-${subproject}-${property})
    set(${var} "${v}" PARENT_SCOPE)
endfunction()


function(_c4_set_subproject_property subproject property value)
    c4_dbg("setting subproj prop: ${subproject}: ${property}=${value}")
    set_property(GLOBAL PROPERTY _c4_subproject-${subproject}-${property} "${value}")
endfunction()
function(_c4_append_subproject_property subproject property value)
    _c4_get_subproject_property(${subproject} ${property} cval)
    if(cval)
        list(APPEND cval ${value})
    else()
        set(cval ${value})
    endif()
    _c4_set_subproject_property(${subproject} ${property} ${cval})
endfunction()


function(_c4_is_incorporated subproj out)
    if("${subproj}" STREQUAL "${_c4_root_proj}")
        c4_dbg("${subproj} is incorporated? root proj, no")
        set(${out} OFF PARENT_SCOPE)
    else()
        _c4_get_subproject_property(${subproj} INCORPORATE inc)
        c4_dbg("${subproj} is incorporated? not root proj, incorporate=${inc}")
        set(${out} ${inc} PARENT_SCOPE)
    endif()
endfunction()


function(c4_dbg_subproject subproject)
    set(props AVAILABLE IMPORTER SRC_DIR BIN_DIR DEPENDENCIES FOLDER INCORPORATE)
    foreach(p ${props})
        _c4_get_subproject_property(${subproject} ${p} pv)
        c4_dbg("${subproject}: ${p}=${pv}")
    endforeach()
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

function(c4_import_remote_proj name dir)
    _c4_handle_args(_ARGS ${ARGN}
        _ARGS0
            EXCLUDE_FROM_ALL
        _ARGS1
            SUBDIR       # path to the subdirectory where the CMakeLists file is to be found.
            IMPORTED_DIR # [output] path to the location where the proj was found or downloaded to
        _ARGSN
            OVERRIDE   # a list of variable name+value pairs
                       # these variables will be set with c4_override()
                       # before calling add_subdirectory()
            REMOTE     # to specify url, repo, tag, or branch,
                       # pass the needed arguments after dir.
                       # These arguments will be forwarded to ExternalProject_Add()
            SET_FOLDER_TARGETS   # Set the folder of the given targets using
                                 # c4_set_folder_remote_project_targets().
                                 # The first expected argument is the folder,
                                 # and the remaining arguments are the targets
                                 # which we want to set the folder.
    )
    set(srcdir_in_out "${dir}")
    c4_download_remote_proj(${name} srcdir_in_out ${_REMOTE})
    if(_IMPORTED_DIR)
        if("${srcdir_in_out}" STREQUAL "")
            c4_err("srcdir is empty")
        endif()
        set(${_IMPORTED_DIR} ${srcdir_in_out} PARENT_SCOPE)
    endif()
    if(_SUBDIR)
        set(srcdir_in_out "${srcdir_in_out}/${_SUBDIR}")
    endif()
    _c4_set_subproject_property(${name} SRC_DIR "${srcdir_in_out}")
    if(_EXCLUDE_FROM_ALL)
        set(excl EXCLUDE_FROM_ALL)
    endif()
    c4_add_subproj(${name} "${srcdir_in_out}" "${dir}/build" OVERRIDE ${_OVERRIDE} ${excl})
    #
    if(_SET_FOLDER_TARGETS)
        c4_set_folder_remote_project_targets(${_SET_FOLDER_TARGETS})
    endif()
endfunction()


# download remote projects while running cmake
# to specify url, repo, tag, or branch,
# pass the needed arguments after dir.
# These arguments will be forwarded to ExternalProject_Add()
function(c4_download_remote_proj name candidate_dir)
    # https://crascit.com/2015/07/25/cmake-gtest/
    # (via https://stackoverflow.com/questions/15175318/cmake-how-to-build-external-projects-and-include-their-targets)
    set(dir ${${candidate_dir}})
    if("${dir}" STREQUAL "")
        set(dir "${CMAKE_BINARY_DIR}/extern/${name}")
    endif()
    set(cvar _${_c4_uprefix}_DOWNLOAD_${name}_LOCATION)
    set(cval ${${cvar}})
    #
    # was it already downloaded in this project?
    if(NOT ("${cval}" STREQUAL ""))
        if(EXISTS "${cval}")
            c4_log("${name} was previously imported into this project - found at \"${cval}\"!")
            set(${candidate_dir} "${cval}" PARENT_SCOPE)
            return()
        else()
            c4_log("${name} was previously imported into this project - but was NOT found at \"${cval}\"!")
        endif()
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
cmake_minimum_required(VERSION 3.7)
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
        set(C4_EXTERN_DIR "$ENV{C4_EXTERN_DIR}")
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


function(_c4_set_target_folder target subfolder)
    string(FIND "${subfolder}" "/" pos)
    if(pos EQUAL 0)
        if("${_c4_curr_path}" STREQUAL "")
            string(SUBSTRING "${subfolder}" 1 -1 sf)
            set_target_properties(${target} PROPERTIES
                FOLDER "${sf}")
        else()
            set_target_properties(${target} PROPERTIES
                FOLDER "${subfolder}")
        endif()
    elseif("${subfolder}" STREQUAL "")
        set_target_properties(${target} PROPERTIES
            FOLDER "${_c4_curr_path}")
    else()
        if("${_c4_curr_path}" STREQUAL "")
            set_target_properties(${target} PROPERTIES
                FOLDER "${subfolder}")
        else()
            set_target_properties(${target} PROPERTIES
                FOLDER "${_c4_curr_path}/${subfolder}")
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
function(c4_add_executable target)
    c4_add_target(${target} EXECUTABLE ${ARGN})
endfunction(c4_add_executable)


# a convenience alias to c4_add_target()
function(c4_add_library target)
    c4_add_target(${target} LIBRARY ${ARGN})
endfunction(c4_add_library)


# example: c4_add_target(ryml LIBRARY SOURCES ${SRC})
function(c4_add_target target)
    c4_dbg("adding target: ${target}: ${ARGN}")
    set(opt0arg
        LIBRARY     # the target is a library
        EXECUTABLE  # the target is an executable
        WIN32       # the executable is WIN32
        SANITIZE    # deprecated
    )
    set(opt1arg
        LIBRARY_TYPE    # override global setting for C4_LIBRARY_TYPE
        SHARED_MACRO    # the name of the macro to turn on export/import symbols
                        # for compiling the library as a windows DLL.
                        # defaults to ${_c4_uprefix}SHARED.
        SHARED_EXPORTS  # the name of the macro to turn on export of symbols
                        # for compiling the library as a windows DLL.
                        # defaults to ${_c4_uprefix}EXPORTS.
        SOURCE_ROOT     # the directory where relative source paths
                        # should be resolved. when empty,
                        # use CMAKE_CURRENT_SOURCE_DIR
        FOLDER          # IDE folder to group the target in
        SANITIZERS      # (deprecated) outputs the list of sanitize targets in this var
        SOURCE_TRANSFORM  # WIP
    )
    set(optnarg
        INCORPORATE  # incorporate these libraries into this target,
                     # subject to ${_c4_uprefix}STANDALONE and C4_STANDALONE
        SOURCES  PUBLIC_SOURCES  INTERFACE_SOURCES  PRIVATE_SOURCES
        HEADERS  PUBLIC_HEADERS  INTERFACE_HEADERS  PRIVATE_HEADERS
        INC_DIRS PUBLIC_INC_DIRS INTERFACE_INC_DIRS PRIVATE_INC_DIRS
        LIBS     PUBLIC_LIBS     INTERFACE_LIBS     PRIVATE_LIBS
        DEFS     PUBLIC_DEFS     INTERFACE_DEFS     PRIVATE_DEFS    # defines
        CFLAGS   PUBLIC_CFLAGS   INTERFACE_CFLAGS   PRIVATE_CFLAGS  # compiler flags. TODO: linker flags
        DLLS           # DLLs required by this target
        MORE_ARGS
    )
    cmake_parse_arguments("" "${opt0arg}" "${opt1arg}" "${optnarg}" ${ARGN})
    #
    if(_SANITIZE)
        c4_err("SANITIZE is deprecated")
    endif()
    if(_SANITIZERS)
        c4_err("SANITIZERS is deprecated")
    endif()

    if(${_LIBRARY})
        set(_what LIBRARY)
    elseif(${_EXECUTABLE})
        set(_what EXECUTABLE)
    else()
        c4_err("must be either LIBRARY or EXECUTABLE")
    endif()

    _c4_handle_arg(SHARED_MACRO ${_c4_uprefix}MACRO)
    _c4_handle_arg(SHARED_EXPORTS ${_c4_uprefix}EXPORTS)
    _c4_handle_arg_or_fallback(SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
    function(_c4_transform_to_full_path list all)
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
    _c4_transform_to_full_path(          _SOURCES allsrc)
    _c4_transform_to_full_path(          _HEADERS allsrc)
    _c4_transform_to_full_path(   _PUBLIC_SOURCES allsrc)
    _c4_transform_to_full_path(_INTERFACE_SOURCES allsrc)
    _c4_transform_to_full_path(  _PRIVATE_SOURCES allsrc)
    _c4_transform_to_full_path(   _PUBLIC_HEADERS allsrc)
    _c4_transform_to_full_path(_INTERFACE_HEADERS allsrc)
    _c4_transform_to_full_path(  _PRIVATE_HEADERS allsrc)
    create_source_group("" "${_SOURCE_ROOT}" "${allsrc}")
    # is the target name prefixed with the project prefix?
    string(REGEX MATCH "${_c4_prefix}::.*" target_is_prefixed "${target}")
        if(${_EXECUTABLE})
            c4_dbg("adding executable: ${target}")
            if(WIN32)
                if(${_WIN32})
                    list(APPEND _MORE_ARGS WIN32)
                endif()
            endif()
            add_executable(${target} ${_MORE_ARGS})
            if(NOT target_is_prefixed)
                add_executable(${_c4_prefix}::${target} ALIAS ${target})
            endif()
            set(src_mode PRIVATE)
            set(tgt_type PUBLIC)
            set(compiled_target ON)
            set_target_properties(${target} PROPERTIES VERSION ${${_c4_prefix}_VERSION})
        elseif(${_LIBRARY})
            c4_dbg("adding library: ${target}")
            set(_blt ${C4_LIBRARY_TYPE})  # build library type
            if(NOT "${_LIBRARY_TYPE}" STREQUAL "")
                set(_blt ${_LIBRARY_TYPE})
            endif()
            if("${_blt}" STREQUAL "")
            endif()
            #
            if("${_blt}" STREQUAL "INTERFACE")
                c4_dbg("adding interface library ${target}")
                add_library(${target} INTERFACE)
                set(src_mode INTERFACE)
                set(tgt_type INTERFACE)
                set(compiled_target OFF)
            else()
                if("${_blt}" STREQUAL "")
                    # obey BUILD_SHARED_LIBS (ie, either static or shared library)
                    c4_dbg("adding library ${target} (defer to BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}) --- ${_MORE_ARGS}")
                    add_library(${target} ${_MORE_ARGS})
                    if(BUILD_SHARED_LIBS)
                        set(_blt SHARED)
                    else()
                        set(_blt STATIC)
                    endif()
                else()
                    c4_dbg("adding library ${target} with type ${_blt}")
                    add_library(${target} ${_blt} ${_MORE_ARGS})
                endif()
                # libraries
                set(src_mode PRIVATE)
                set(tgt_type PUBLIC)
                set(compiled_target ON)
                set_target_properties(${target} PROPERTIES VERSION ${${_c4_prefix}_VERSION})
                if("${_blt}" STREQUAL SHARED)
                    set_target_properties(${target} PROPERTIES SOVERSION ${${_c4_prefix}_VERSION})
                endif()
                # exports for shared libraries
                if(WIN32)
                    if("${_blt}" STREQUAL SHARED)
                        set_target_properties(${target} PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
                        target_compile_definitions(${target} PUBLIC ${_SHARED_MACRO})
                        target_compile_definitions(${target} PRIVATE $<BUILD_INTERFACE:${_SHARED_EXPORTS}>)
                        # save the name of the macro for later use when(if) incorporating this library
                        c4_set_target_prop(${target} SHARED_EXPORTS ${_SHARED_EXPORTS})
                    endif()  # shared lib
                endif() # win32
            endif() # interface or lib
            if(NOT target_is_prefixed)
                add_library(${_c4_prefix}::${target} ALIAS ${target})
            endif()
        endif(${_EXECUTABLE})

        if(src_mode STREQUAL "PUBLIC")
            c4_add_target_sources(${target}
                PUBLIC    "${_SOURCES};${_HEADERS};${_PUBLIC_SOURCES};${_PUBLIC_HEADERS}"
                INTERFACE "${_INTERFACE_SOURCES};${_INTERFACE_HEADERS}"
                PRIVATE   "${_PRIVATE_SOURCES};${_PRIVATE_HEADERS}")
        elseif(src_mode STREQUAL "INTERFACE")
            c4_add_target_sources(${target}
                PUBLIC    "${_PUBLIC_SOURCES};${_PUBLIC_HEADERS}"
                INTERFACE "${_SOURCES};${_HEADERS};${_INTERFACE_SOURCES};${_INTERFACE_HEADERS}"
                PRIVATE   "${_PRIVATE_SOURCES};${_PRIVATE_HEADERS}")
        elseif(src_mode STREQUAL "PRIVATE")
            c4_add_target_sources(${target}
                PUBLIC    "${_PUBLIC_SOURCES};${_PUBLIC_HEADERS}"
                INTERFACE "${_INTERFACE_SOURCES};${_INTERFACE_HEADERS}"
                PRIVATE   "${_SOURCES};${_HEADERS};${_PRIVATE_SOURCES};${_PRIVATE_HEADERS}")
        elseif()
            c4_err("${target}: adding sources: invalid source mode")
        endif()
        _c4_set_tgt_prop(${target} C4_SOURCE_ROOT "${_SOURCE_ROOT}")

        if(_INC_DIRS)
            c4_dbg("${target}: adding include dirs ${_INC_DIRS} [from target: ${tgt_type}]")
            target_include_directories(${target} "${tgt_type}" ${_INC_DIRS})
        endif()
        if(_PUBLIC_INC_DIRS)
            c4_dbg("${target}: adding PUBLIC include dirs ${_PUBLIC_INC_DIRS}")
            target_include_directories(${target} PUBLIC ${_PUBLIC_INC_DIRS})
        endif()
        if(_INTERFACE_INC_DIRS)
            c4_dbg("${target}: adding INTERFACE include dirs ${_INTERFACE_INC_DIRS}")
            target_include_directories(${target} INTERFACE ${_INTERFACE_INC_DIRS})
        endif()
        if(_PRIVATE_INC_DIRS)
            c4_dbg("${target}: adding PRIVATE include dirs ${_PRIVATE_INC_DIRS}")
            target_include_directories(${target} PRIVATE ${_PRIVATE_INC_DIRS})
        endif()

        if(_LIBS)
            _c4_link_with_libs(${target} "${tgt_type}" "${_LIBS}" "${_INCORPORATE}")
        endif()
        if(_PUBLIC_LIBS)
            _c4_link_with_libs(${target} PUBLIC "${_PUBLIC_LIBS}" "${_INCORPORATE}")
        endif()
        if(_INTERFACE_LIBS)
            _c4_link_with_libs(${target} INTERFACE "${_INTERFACE_LIBS}" "${_INCORPORATE}")
        endif()
        if(_PRIVATE_LIBS)
            _c4_link_with_libs(${target} PRIVATE "${_PRIVATE_LIBS}" "${_INCORPORATE}")
        endif()

        if(compiled_target)
            if(_FOLDER)
                _c4_set_target_folder(${target} "${_FOLDER}")
            else()
                _c4_set_target_folder(${target} "")
            endif()
            # cxx standard
            c4_target_inherit_cxx_standard(${target})
            # compile flags
            set(_more_flags
                ${${_c4_uprefix}CXX_FLAGS}
                ${${_c4_uprefix}C_FLAGS}
                ${${_c4_uprefix}CXX_FLAGS_OPT})
            if(_more_flags)
                get_target_property(_flags ${target} COMPILE_OPTIONS)
                if(_flags)
                    set(_more_flags ${_flags};${_more_flags})
                endif()
                c4_dbg("${target}: COMPILE_FLAGS=${_more_flags}")
                target_compile_options(${target} PRIVATE "${_more_flags}")
            endif()
            # linker flags
            set(_link_flags ${${_c4_uprefix}CXX_LINKER_FLAGS})
            if(_link_flags)
                get_target_property(_flags ${target} LINK_OPTIONS)
                if(_flags)
                    set(_link_flags ${_flags};${_more_flags})
                endif()
                c4_dbg("${target}: LINKER_FLAGS=${_link_flags}")
                target_link_options(${target} PUBLIC "${_link_flags}")
            endif()
            # static analysis
            if(${_c4_uprefix}LINT)
                c4_static_analysis_target(${target} "${_FOLDER}" lint_targets)
            endif()
        endif(compiled_target)

        if(_DEFS)
            target_compile_definitions(${target} "${tgt_type}" ${_DEFS})
        endif()
        if(_PUBLIC_DEFS)
            target_compile_definitions(${target} PUBLIC ${_PUBLIC_DEFS})
        endif()
        if(_INTERFACE_DEFS)
            target_compile_definitions(${target} INTERFACE ${_INTERFACE_DEFS})
        endif()
        if(_PRIVATE_DEFS)
            target_compile_definitions(${target} PRIVATE ${_PRIVATE_DEFS})
        endif()

        if(_CFLAGS)
            target_compile_options(${target} "${tgt_type}" ${_CFLAGS})
        endif()
        if(_PUBLIC_CFLAGS)
            target_compile_options(${target} PUBLIC ${_PUBLIC_CFLAGS})
        endif()
        if(_INTERFACE_CFLAGS)
            target_compile_options(${target} INTERFACE ${_INTERFACE_CFLAGS})
        endif()
        if(_PRIVATE_CFLAGS)
            target_compile_options(${target} PRIVATE ${_PRIVATE_CFLAGS})
        endif()

    # gather dlls so that they can be automatically copied to the target directory
    if(_DLLS)
        c4_append_transitive_property(${target} _C4_DLLS "${_DLLS}")
    endif()

    if(${_EXECUTABLE})
        if(WIN32)
            c4_get_transitive_property(${target} _C4_DLLS transitive_dlls)
            list(REMOVE_DUPLICATES transitive_dlls)
            foreach(_dll ${transitive_dlls})
                if(_dll)
                    c4_dbg("enable copy of dll to target file dir: ${_dll} ---> $<TARGET_FILE_DIR:${target}>")
                    add_custom_command(TARGET ${target} POST_BUILD
                        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_dll}" "$<TARGET_FILE_DIR:${target}>"
                        )
                else()
                    message(WARNING "dll required by ${_c4_prefix}/${target} was not found, so cannot copy: ${_dll}")
                endif()
            endforeach()
        endif()
    endif()
endfunction() # add_target


function(_c4_link_with_libs target link_type libs incorporate)
    foreach(lib ${libs})
        # add targets that are DLLs
        if(WIN32)
            if(TARGET ${lib})
                get_target_property(lib_type ${lib} TYPE)
                if(lib_type STREQUAL SHARED_LIBRARY)
                    c4_append_transitive_property(${target} _C4_DLLS "$<TARGET_FILE:${lib}>")
                endif()
            endif()
        endif()
        _c4_lib_is_incorporated(${lib} isinc)
        if(isinc OR (incorporate AND ${_c4_uprefix}STANDALONE))
            c4_log("-----> target ${target} ${link_type} incorporating lib ${lib}")
            _c4_incorporate_lib(${target} ${link_type} ${lib})
        else()
            c4_dbg("${target} ${link_type} linking with lib ${lib}")
            target_link_libraries(${target} ${link_type} ${lib})
        endif()
    endforeach()
endfunction()


function(_c4_lib_is_incorporated lib ret)
    c4_dbg("${lib}: is incorporated?")
    if(NOT TARGET ${lib})
        c4_dbg("${lib}: no, not a target")
        set(${ret} OFF PARENT_SCOPE)
    else()
        c4_get_target_prop(${lib} INCORPORATING_TARGETS inc)
        if(inc)
            c4_dbg("${lib}: is incorporated!")
            set(${ret} ON PARENT_SCOPE)
        else()
            c4_dbg("${lib}: is not incorporated!")
            set(${ret} OFF PARENT_SCOPE)
        endif()
    endif()
endfunction()


function(_c4_incorporate_lib target link_type lib)
    c4_dbg("target ${target}: incorporating lib ${lib} [${link_type}]")
    _c4_get_tgt_prop(srcroot ${lib} C4_SOURCE_ROOT)
    #
    c4_append_target_prop(${lib} INCORPORATING_TARGETS ${target})
    c4_append_target_prop(${target} INCORPORATED_TARGETS ${lib})
    #
    _c4_get_tgt_prop(lib_src ${lib} SOURCES)
    if(lib_src)
        create_source_group("${lib}" "${srcroot}" "${lib_src}")
        c4_add_target_sources(${target} INCORPORATED_FROM ${lib} PRIVATE ${lib_src})
    endif()
    #
    _c4_get_tgt_prop(lib_isrc ${lib} INTERFACE_SOURCES)
    if(lib_isrc)
        create_source_group("${lib}" "${srcroot}" "${lib_isrc}")
        c4_add_target_sources(${target} INCORPORATED_FROM ${lib} INTERFACE ${lib_isrc})
    endif()
    #
    _c4_get_tgt_prop(lib_psrc ${lib} PRIVATE_SOURCES)
    if(lib_psrc)
        create_source_group("${lib}" "${srcroot}" "${lib_psrc}")
        c4_add_target_sources(${target} INCORPORATED_FROM ${lib} INTERFACE ${lib_psrc})
    endif()
    #
    #
    _c4_get_tgt_prop(lib_incs ${lib} INCLUDE_DIRECTORIES)
    if(lib_incs)
        target_include_directories(${target} PUBLIC ${lib_incs})
    endif()
    #
    _c4_get_tgt_prop(lib_iincs ${lib} INTERFACE_INCLUDE_DIRECTORIES)
    if(lib_iincs)
        target_include_directories(${target} INTERFACE ${lib_iincs})
    endif()
    #
    #
    _c4_get_tgt_prop(lib_lib ${lib} LINK_LIBRARIES)
    if(lib_lib)
        target_link_libraries(${target} PUBLIC ${lib_lib})
    endif()
    _c4_get_tgt_prop(lib_ilib ${lib} INTERFACE_LIBRARY)
    if(lib_ilib)
        target_link_libraries(${target} INTERFACE ${lib_ilib})
    endif()
    #
    #
    c4_get_target_prop(${lib} SHARED_EXPORTS lib_exports)
    if(lib_exports)
        target_compile_definitions(${target} PRIVATE $<BUILD_INTERFACE:${lib_exports}>)
    endif()
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#
function(c4_add_target_sources target)
    # https://steveire.wordpress.com/2016/08/09/opt-in-header-only-libraries-with-cmake/
    _c4_handle_args(_ARGS ${ARGN}
      _ARGS1  # one-value macro arguments
        INCORPORATED_FROM
        TRANSFORM # Transform types:
                  #   * NONE - do not transform the sources
                  #   * UNITY
                  #   * UNITY_HDR
                  #   * SINGLE_HDR
                  #   * SINGLE_UNIT
      _ARGSN  # multi-value macro arguments
        PUBLIC
        INTERFACE
        PRIVATE
    )
    if(("${_TRANSFORM}" STREQUAL "GLOBAL") OR ("${_TRANSFORM}" STREQUAL ""))
        set(_TRANSFORM ${C4_SOURCE_TRANSFORM})
    endif()
    if("${_TRANSFORM}" STREQUAL "")
        set(_TRANSFORM NONE)
    endif()
    #
    # is this target an interface?
    set(_is_iface FALSE)
    _c4_get_tgt_prop(target_type ${target} TYPE)
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
        c4_dbg("target ${target}: source transform: NONE!")
        #
        # do not transform the sources
        #
        if(_PUBLIC)
            c4_dbg("target=${target} PUBLIC sources: ${_PUBLIC}")
            c4_append_target_prop(${target} PUBLIC_SRC "${_PUBLIC}")
            if(_INCORPORATED_FROM)
                c4_append_target_prop(${target} PUBLIC_SRC_${_INCORPORATED_FROM} "${_PUBLIC}")
            else()
                c4_append_target_prop(${target} PUBLIC_SRC_${target} "${_PUBLIC}")
            endif()
            target_sources(${target} PUBLIC "${_PUBLIC}")
        endif()
        if(_INTERFACE)
            c4_dbg("target=${target} INTERFACE sources: ${_INTERFACE}")
            c4_append_target_prop(${target} INTERFACE_SRC "${_INTERFACE}")
            if(_INCORPORATED_FROM)
                c4_append_target_prop(${target} INTERFACE_SRC_${_INCORPORATED_FROM} "${_INTERFACE}")
            else()
                c4_append_target_prop(${target} INTERFACE_SRC_${target} "${_INTERFACE}")
            endif()
            target_sources(${target} INTERFACE "${_INTERFACE}")
        endif()
        if(_PRIVATE)
            c4_dbg("target=${target} PRIVATE sources: ${_PRIVATE}")
            c4_append_target_prop(${target} PRIVATE_SRC "${_PRIVATE}")
            if(_INCORPORATED_FROM)
                c4_append_target_prop(${target} PRIVATE_SRC_${_INCORPORATED_FROM} "${_PRIVATE}")
            else()
                c4_append_target_prop(${target} PRIVATE_SRC_${target} "${_PRIVATE}")
            endif()
            target_sources(${target} PRIVATE "${_PRIVATE}")
        endif()
        #
    elseif("${_TRANSFORM}" STREQUAL "UNITY")
        c4_dbg("target ${target}: source transform: UNITY!")
        c4_err("source transformation not implemented")
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
            c4_append_target_prop(${target} PUBLIC_SRC
                $<BUILD_INTERFACE:${hpublic};${out}>
                $<INSTALL_INTERFACE:${hpublic};${out}>)
            target_sources(${target} PUBLIC
                $<BUILD_INTERFACE:${hpublic};${out}>
                $<INSTALL_INTERFACE:${hpublic};${out}>)
        endif()
        if(_INTERFACE)
            c4_append_target_prop(${target} INTERFACE_SRC
                $<BUILD_INTERFACE:${hinterface}>
                $<INSTALL_INTERFACE:${hinterface}>)
            target_sources(${target} INTERFACE
                $<BUILD_INTERFACE:${hinterface}>
                $<INSTALL_INTERFACE:${hinterface}>)
        endif()
        if(_PRIVATE)
            c4_append_target_prop(${target} PRIVATE_SRC
                $<BUILD_INTERFACE:${hprivate}>
                $<INSTALL_INTERFACE:${hprivate}>)
            target_sources(${target} PRIVATE
                $<BUILD_INTERFACE:${hprivate}>
                $<INSTALL_INTERFACE:${hprivate}>)
        endif()
    elseif("${_TRANSFORM}" STREQUAL "UNITY_HDR")
        c4_dbg("target ${target}: source transform: UNITY_HDR!")
        c4_err("target ${target}: source transformation not implemented")
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
        c4_dbg("target ${target}: source transform: SINGLE_HDR!")
        c4_err("target ${target}: source transformation not implemented")
        #
        # concatenate everything into a single header file
        #
        _c4cat_get_outname(${target} "all" ${C4_GEN_HDR_EXT} out)
        _c4cat_filter_srcs_hdrs("${_c4al_SOURCES}" ch)
        c4_cat_sources("${ch}" "${out}" ${umbrella})
        #
    elseif("${_TRANSFORM}" STREQUAL "SINGLE_UNIT")
        c4_dbg("target ${target}: source transform: SINGLE_UNIT!")
        c4_err("target ${target}: source transformation not implemented")
        #
        # concatenate:
        #  * all compilation units into a single compilation unit
        #  * all headers into a single header
        #
        _c4cat_get_outname(${target} "src" ${C4_GEN_SRC_EXT} out)
        _c4cat_get_outname(${target} "hdr" ${C4_GEN_SRC_EXT} out)
        _c4cat_filter_srcs_hdrs("${_c4al_SOURCES}" ch)
        c4_cat_sources("${ch}" "${out}" ${umbrella})
    else()
        c4_err("unknown transform type: ${transform_type}. Must be one of GLOBAL;NONE;UNITY;TO_HEADERS;SINGLE_HEADER")
    endif()
endfunction()


# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# WIP, under construction (still incomplete)
# see: https://github.com/pr0g/cmake-examples
# see: https://cliutils.gitlab.io/modern-cmake/


function(c4_install_target target)
    _c4_handle_args(_ARGS ${ARGN}
      _ARGS1  # one-value macro arguments
        EXPORT # the name of the export target. default: see below.
    )
    _c4_handle_arg(EXPORT "${_c4_prefix}-export")
    #
    c4_dbg("installing target: ${target} ${ARGN}")
    #_c4_is_incorporated(${_c4_prefix} inc)
    #if(inc)
    #    c4_dbg("this project is INCORPORATEd. skipping install of targets")
    #    return()
    #endif()
    #
    _c4_setup_install_vars()
    install(TARGETS ${target}
        EXPORT ${_EXPORT}
        RUNTIME DESTINATION ${_RUNTIME_INSTALL_DIR}  #COMPONENT runtime
        BUNDLE  DESTINATION ${_RUNTIME_INSTALL_DIR}  #COMPONENT runtime
        LIBRARY DESTINATION ${_LIBRARY_INSTALL_DIR}  #COMPONENT runtime
        ARCHIVE DESTINATION ${_ARCHIVE_INSTALL_DIR}  #COMPONENT development
        OBJECTS DESTINATION ${_OBJECTS_INSTALL_DIR}  #COMPONENT development
        INCLUDES DESTINATION ${_INCLUDE_INSTALL_DIR} #COMPONENT development
        PUBLIC_HEADER DESTINATION ${_INCLUDE_INSTALL_DIR} #COMPONENT development
        )
    c4_install_sources(${target} include)
    #
    # on windows, install also required DLLs
    if(WIN32)
        get_target_property(target_type ${target} TYPE)
        if("${target_type}" STREQUAL "EXECUTABLE")
            c4_get_transitive_property(${target} _C4_DLLS transitive_dlls)
            if(transitive_dlls)
                c4_dbg("${target}: installing dlls: ${transitive_dlls} to ${_RUNTIME_INSTALL_DIR}")
                list(REMOVE_DUPLICATES transitive_dlls)
                install(FILES ${transitive_dlls}
                    DESTINATION ${_RUNTIME_INSTALL_DIR}  # shouldn't it be _LIBRARY_INSTALL_DIR?
                    #COMPONENT runtime
                    )
            endif()
        endif()
    endif()
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


function(c4_install_sources target destination)
    c4_dbg("target ${target}: installing sources to ${destination}")
    # executables have no sources requiring install
    _c4_get_tgt_prop(target_type ${target} TYPE)
    if(target_type STREQUAL "EXECUTABLE")
        c4_dbg("target ${target}: is executable, skipping source install")
        return()
    endif()
    # install source from the target and incorporated targets
    c4_get_target_prop(${target} INCORPORATED_TARGETS inctargets)
    if(inctargets)
        set(targets "${inctargets};${target}")
    else()
        set(targets "${target}")
    endif()
    foreach(t ${targets})
        _c4_get_tgt_prop(srcroot ${t} C4_SOURCE_ROOT)
        # get the sources from the target
        #
        c4_get_target_prop(${t} PUBLIC_SRC_${t} src)
        if(src)
            _c4cat_filter_hdrs("${src}" srcf)
            _c4cat_filter_additional_exts("${src}" add)
            c4_install_files("${srcf}" "${destination}" "${srcroot}")
            c4_install_files("${add}" "${destination}" "${srcroot}")
        endif()
        #
        c4_get_target_prop(${t} PRIVATE_SRC_${t} psrc)
        if(psrc)
            _c4cat_filter_hdrs("${psrc}" psrcf)
            _c4cat_filter_additional_exts("${psrc}" add)
            c4_install_files("${psrcf}" "${destination}" "${srcroot}")
            c4_install_files("${add}" "${destination}" "${srcroot}")
        endif()
        #
        c4_get_target_prop(${t} INTERFACE_SRC_${t} isrc)
        if(isrc)
            _c4cat_filter_srcs_hdrs("${isrc}" isrcf)
            _c4cat_filter_additional_exts("${isrc}" add)
            c4_install_files("${isrcf}" "${destination}" "${srcroot}")
            c4_install_files("${add}" "${destination}" "${srcroot}")
        endif()
        #
        c4_get_target_prop(${t} ADDFILES addfiles)
        if(addfiles)
            foreach(af ${addfiles})
                string(REGEX REPLACE "(.*)!!(.*)!!(.*)" "\\1;\\2;\\3" li "${af}")
                list(GET li 0 files)
                list(GET li 1 dst)
                list(GET li 2 relative_to)
                string(REPLACE "%%%" ";" files "${files}")
                c4_install_files("${files}" "${dst}" "${relative_to}")
            endforeach()
        endif()
        #
        c4_get_target_prop(${t} ADDDIRS adddirs)
        if(adddirs)
            foreach(af ${adddirs})
                string(REGEX REPLACE "(.*)!!(.*)!!(.*)" "\\1;\\2;\\3" li "${af}")
                list(GET li 0 dirs)
                list(GET li 1 dst)
                list(GET li 2 relative_to)
                string(REPLACE "%%%" ";" dirs "${files}")
                c4_install_dirs("${dirs}" "${dst}" "${relative_to}")
            endforeach()
        endif()
    endforeach()
endfunction()


function(c4_install_target_add_files target files destination relative_to)
    c4_dbg("installing additional files for target ${target}, destination=${destination}: ${files}")
    string(REPLACE ";" "%%%" rfiles "${files}")
    c4_append_target_prop(${target} ADDFILES "${rfiles}!!${destination}!!${relative_to}")
    #
    _c4_is_incorporated(${_c4_prefix} inc)
    if(inc)
        c4_dbg("this project is INCORPORATEd. skipping install of targets")
        return()
    endif()
    c4_install_files("${files}" "${destination}" "${relative_to}")
endfunction()


function(c4_install_target_add_dirs target dirs destination relative_to)
    c4_dbg("installing additional dirs for target ${target}, destination=${destination}: ${dirs}")
    string(REPLACE ";" "%%%" rdirs "${dirs}")
    c4_append_target_prop(${target} ADDDIRS "${rdirs}!!${destination}!!${relative_to}")
    #
    _c4_is_incorporated(${_c4_prefix} inc)
    if(inc)
        c4_dbg("this project is INCORPORATEd. skipping install of targets")
        return()
    endif()
    c4_install_dirs("${dirs}" "${destination}" "${relative_to}")
endfunction()


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


function(c4_install_exports)
    _c4_handle_args(_ARGS ${ARGN}
      _ARGS1  # one-value macro arguments
        PREFIX     # override the c4 project-wide prefix. This will be used in the cmake
        TARGET     # the name of the exports target
        NAMESPACE  # the namespace for the targets
      _ARGSN  # multi-value macro arguments
        DEPENDENCIES
    )
    #
    _c4_handle_arg(PREFIX    "${_c4_prefix}")
    _c4_handle_arg(TARGET    "${_c4_prefix}-export")
    _c4_handle_arg(NAMESPACE "${_c4_prefix}::")
    #
    c4_dbg("installing exports: ${ARGN}")
    #_c4_is_incorporated(${_c4_prefix} inc)
    #if(inc)
    #    c4_dbg("this project is INCORPORATEd. skipping install of exports")
    #    return()
    #endif()
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
include(CMakeFindDependencyMacro)
")
        foreach(d ${_DEPENDENCIES})
            _c4_is_incorporated(${d} inc)
            if(inc)
                c4_dbg("install: dependency ${d} is INCORPORATEd, skipping check")
                continue()
            endif()
            c4_dbg("install: adding dependency check for ${d}")
            set(deps "${deps}find_dependency(${d} REQUIRED)
")
        endforeach()
        set(deps "${deps}#-----------------------------")
    endif()
    #
    # cfg_dst is the path relative to install root where the export
    # should be installed; cfg_dst_rel is the path from there to
    # the install root
    macro(__c4_install_exports cfg_dst cfg_dst_rel)
        # make sure that different exports are staged in different directories
        set(case ${CMAKE_CURRENT_BINARY_DIR}/export_cases/${cfg_dst})
        file(MAKE_DIRECTORY ${case})
        #
        file(TO_CMAKE_PATH "${targets_file}" _targets_file_normalized)
        file(TO_CMAKE_PATH "${cfg_dst}" _cfg_dst_normalized)
        install(EXPORT "${_TARGET}"
            FILE "${_targets_file_normalized}"
            NAMESPACE "${_NAMESPACE}"
            DESTINATION "${_cfg_dst_normalized}")
        export(EXPORT ${_TARGET}
            FILE "${_targets_file_normalized}"
            NAMESPACE "${_NAMESPACE}")
        #
        # Config files
        # the module below has nice docs in it; do read them
        # to understand the macro calls below
        include(CMakePackageConfigHelpers)
        set(cfg ${case}/${_PREFIX}Config.cmake)
        set(cfg_ver ${case}/${_PREFIX}ConfigVersion.cmake)
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
        file(TO_CMAKE_PATH "${cfg_dst}" _cfg_dst_normalized)
        install(FILES ${cfg} ${cfg_ver} DESTINATION ${_cfg_dst_normalized})
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
        __c4_install_exports(${_ARCHIVE_INSTALL_DIR}/cmake/${_c4_prefix} "../../..")
        #__c4_install_exports(${_ARCHIVE_INSTALL_DIR}/${_c4_prefix}.framework/Resources/ "../../..")
    elseif(UNIX OR (CMAKE_SYSTEM_NAME STREQUAL UNIX) OR (CMAKE_SYSTEM_NAME STREQUAL Linux) OR (CMAKE_SYSTEM_NAME STREQUAL Generic))
        __c4_install_exports(${_ARCHIVE_INSTALL_DIR}/cmake/${_c4_prefix} "../../..")
    else()
        c4_err("unknown platform. CMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME} CMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}")
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


function(c4_get_target_installed_headers target out)
    c4_get_target_prop(${target} INCORPORATED_TARGETS inctargets)
    if(inctargets)
        set(targets "${inctargets};${target}")
    else()
        set(targets "${target}")
    endif()
    set(hdrs)
    foreach(t ${targets})
        _c4_get_tgt_prop(srcroot ${t} C4_SOURCE_ROOT)
        #
        c4_get_target_prop(${t} PUBLIC_SRC_${t} src)
        if(src)
            _c4cat_filter_hdrs("${src}" srcf)
            if(thdrs)
                set(thdrs "${thdrs};${srcf}")
            else()
                set(thdrs "${srcf}")
            endif()
        endif()
        #
        c4_get_target_prop(${t} PRIVATE_SRC_${t} psrc)
        if(src)
            _c4cat_filter_hdrs("${psrc}" psrcf)
            if(thdrs)
                set(thdrs "${thdrs};${psrcf}")
            else()
                set(thdrs "${psrcf}")
            endif()
        endif()
        #
        c4_get_target_prop(${t} INTERFACE_SRC_${t} isrc)
        if(src)
            _c4cat_filter_hdrs("${isrc}" isrcf)
            if(thdrs)
                set(thdrs "${thdrs};${isrcf}")
            else()
                set(thdrs "${isrcf}")
            endif()
        endif()
        #
        foreach(h ${thdrs})
            file(RELATIVE_PATH rf "${srcroot}" "${h}")
            list(APPEND hdrs "${rf}")
        endforeach()
    endforeach()
    set(${out} ${hdrs} PARENT_SCOPE)
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
function(c4_setup_testing)
    _c4_handle_args(_ARGS ${ARGN}
        _ARGS0
            GTEST    # download and import googletest
            DOCTEST  # download and import doctest
        _ARGS1
        _ARGSN
    )
    #include(GoogleTest) # this module requires at least cmake 3.9
    c4_dbg("enabling tests")
    # umbrella target for building test binaries
    add_custom_target(${_c4_lprefix}test-build)
    _c4_set_target_folder(${_c4_lprefix}test-build test)
    # umbrella targets for running tests
    if(NOT TARGET test-build)
        add_custom_target(test-build)
        add_custom_target(test-verbose)
        _c4_set_target_folder(test-build "/test")
        _c4_set_target_folder(test-verbose "/test")
    endif()
    function(_def_runner runner)
        set(echo "
CWD=${CMAKE_CURRENT_BINARY_DIR}
----------------------------------
${ARGN}
----------------------------------
")
        add_custom_target(${runner}
            #${CMAKE_COMMAND} -E echo "${echo}"
            COMMAND ${ARGN}
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            DEPENDS ${_c4_lprefix}test-build
            )
        _c4_set_target_folder(${runner} test)
    endfunction()
    _def_runner(${_c4_lprefix}test-run ${CMAKE_CTEST_COMMAND} --output-on-failure ${${_c4_uprefix}CTEST_OPTIONS} -C $<CONFIG>)
    _def_runner(${_c4_lprefix}test-run-verbose ${CMAKE_CTEST_COMMAND} -VV ${${_c4_uprefix}CTEST_OPTIONS} -C $<CONFIG>)
    add_dependencies(test-verbose ${_c4_lprefix}test-run-verbose)
    add_dependencies(test-build ${_c4_lprefix}test-build)
    #
    # import required libraries
    if(_GTEST)
        c4_log("testing requires googletest")
        if(NOT TARGET gtest)
            c4_import_remote_proj(gtest ${CMAKE_CURRENT_BINARY_DIR}/ext/gtest
                REMOTE
                  GIT_REPOSITORY https://github.com/google/googletest.git
                  # this is the latest release to support C++11
                  GIT_TAG release-1.12.1 #GIT_SHALLOW ON
                OVERRIDE
                  BUILD_GTEST ON
                  BUILD_GMOCK OFF
                  gtest_force_shared_crt ON
                  gtest_build_samples OFF
                  gtest_build_tests OFF
                SET_FOLDER_TARGETS ext gtest gtest_main
                EXCLUDE_FROM_ALL
                )
            # old gcc-4.8 support
            if((CMAKE_CXX_COMPILER_ID STREQUAL "GNU") AND
              (CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 4.8) AND
              (CMAKE_CXX_COMPILER_VERSION VERSION_LESS 5.0))
                _c4_get_subproject_property(gtest SRC_DIR _gtest_patch_src_dir)
                apply_patch("${_c4_project_dir}/compat/gtest_gcc-4.8.patch"
                  "${_gtest_patch_src_dir}"
                  "${_gtest_patch_src_dir}/.gtest_gcc-4.8.patch")
                unset(_gtest_patch_src_dir)
                target_compile_options(gtest PUBLIC -include ${_c4_project_dir}/compat/c4/gcc-4.8.hpp)
            endif()
        endif()
    endif()
    if(_DOCTEST)
        c4_log("testing requires doctest")
        if(NOT TARGET doctest)
            c4_import_remote_proj(doctest ${CMAKE_CURRENT_BINARY_DIR}/ext/doctest
                REMOTE
                  GIT_REPOSITORY https://github.com/onqtam/doctest.git
                  GIT_TAG v2.4.11 #GIT_SHALLOW ON
                OVERRIDE
                  DOCTEST_WITH_TESTS OFF
                  DOCTEST_WITH_MAIN_IN_STATIC_LIB ON
                SET_FOLDER_TARGETS ext doctest_with_main
                EXCLUDE_FROM_ALL
                IMPORTED_DIR _doctestdir
                )
            # there is an unitialized access
            c4_add_sanitizer_suppression(MemorySanitizer "[memory]
fun:*doctest*
")
        endif()
    endif()
endfunction(c4_setup_testing)


function(c4_add_test target)
    _c4_handle_args(_ARGS ${ARGN}
      _ARGS0  # zero-value macro arguments
      _ARGS1  # one-value macro arguments
        WORKING_DIRECTORY
      _ARGSN  # multi-value macro arguments
        ARGS
    )
    #
    if(_WORKING_DIRECTORY)
        set(_WORKING_DIRECTORY WORKING_DIRECTORY ${_WORKING_DIRECTORY})
    endif()
    set(cmd_pfx)
    if(CMAKE_CROSSCOMPILING)
        set(cmd_pfx ${CMAKE_CROSSCOMPILING_EMULATOR})
    endif()
    if(${CMAKE_VERSION} VERSION_LESS "3.16.0")
        add_test(NAME ${target}
            COMMAND ${cmd_pfx} "$<TARGET_FILE:${target}>" ${_ARGS}
            ${_WORKING_DIRECTORY})
    else()
        add_test(NAME ${target}
            COMMAND ${cmd_pfx} "$<TARGET_FILE:${target}>" ${_ARGS}
            ${_WORKING_DIRECTORY}
            COMMAND_EXPAND_LISTS)
    endif()
    add_dependencies(${_c4_lprefix}test-build ${target})
    if(NOT CMAKE_CROSSCOMPILING)
        c4_add_valgrind(${target} ${ARGN})
    endif()
    if(${_c4_uprefix}LINT)
        c4_static_analysis_add_tests(${target})  # this will not actually run the executable
    endif()
endfunction(c4_add_test)


# every excess argument is passed on to set_target_properties()
function(c4_add_test_fail_build name srccontent_or_srcfilename)
    #
    set(sdir ${CMAKE_CURRENT_BINARY_DIR}/test_fail_build)
    set(src ${srccontent_or_srcfilename})
    if("${src}" STREQUAL "")
        c4_err("must be given an existing source file name or a non-empty string")
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


# add a test ensuring that a target linking and using code from a library
# successfully compiles and runs against the installed library
function(c4_add_install_link_test library namespace exe_source_code)
    if(CMAKE_CROSSCOMPILING)
        c4_log("cross-compiling: skip install link test")
        return()
    endif()
    if("${library}" STREQUAL "${_c4_prefix}")
        set(testname ${_c4_lprefix}test-install-link)
    else()
        set(testname ${_c4_lprefix}test-install-link-${library})
    endif()
    _c4_add_library_client_test(${library} "${namespace}" "${testname}" "${exe_source_code}")
endfunction()


# add a test ensuring that a target consuming every header in a library
# successfully compiles and runs against the installed library
function(c4_add_install_include_test library namespace)
    if(CMAKE_CROSSCOMPILING)
        c4_log("cross-compiling: skip install include test")
        return()
    endif()
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
    if("${library}" STREQUAL "${_c4_prefix}")
        set(testname ${_c4_lprefix}test-install-include)
    else()
        set(testname ${_c4_lprefix}test-install-include-${library})
    endif()
    _c4_add_library_client_test(${library} "${namespace}" "${testname}" "${src}")
endfunction()


function(_c4_add_library_client_test library namespace pname source_code)
    if("${CMAKE_BUILD_TYPE}" STREQUAL Coverage)
        add_test(NAME ${pname}
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
    set(tout "${pdir}/${pname}-run-out")
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

get_target_property(lib_type ${namespace}${library} TYPE)
if(WIN32 AND (lib_type STREQUAL SHARED_LIBRARY))
    # add the directory containing the DLL to the path
    get_target_property(imported_configs ${namespace}${library} IMPORTED_CONFIGURATIONS)
    message(STATUS \"${namespace}${library}: it's a shared library. imported configs: \${imported_configs}\")
    foreach(cfg \${imported_configs})
        get_target_property(implib ${namespace}${library} IMPORTED_IMPLIB_\${cfg})
        get_target_property(location ${namespace}${library} IMPORTED_LOCATION_\${cfg})
        message(STATUS \"${namespace}${library}: implib_\${cfg}=\${implib}\")
        message(STATUS \"${namespace}${library}: location_\${cfg}=\${location}\")
        break()
    endforeach()
    get_filename_component(dlldir \"\${location}\" DIRECTORY)
    message(STATUS \"${namespace}${library}: dlldir=\${dlldir}\")
    add_custom_target(${pname}-run
        COMMAND \${CMAKE_COMMAND} -E echo \"cd \${dlldir} && \$<TARGET_FILE:${pname}>\"
        COMMAND \$<TARGET_FILE:${pname}>
        DEPENDS ${pname}
        WORKING_DIRECTORY \${dlldir})
else()
    add_custom_target(${pname}-run
        COMMAND \$<TARGET_FILE:${pname}>
        DEPENDS ${pname})
endif()
")
    # The test consists in running the script generated below.
    # We force evaluation of the configuration generator expression
    # by receiving its result via the command line.
    add_test(NAME ${pname}
        COMMAND ${CMAKE_COMMAND} -DCFG_IN=$<CONFIG> -P "${tsrc}"
        )
    # NOTE: in the cmake configure command, be sure to NOT use quotes
    # in -DCMAKE_PREFIX_PATH=\"${CMAKE_INSTALL_PREFIX}\". Use
    # -DCMAKE_PREFIX_PATH=${CMAKE_INSTALL_PREFIX} instead.
    # So here we add a check to make sure the install path has no spaces
    string(FIND "${CMAKE_INSTALL_PREFIX}" " " has_spaces)
    if(NOT (has_spaces EQUAL -1))
        c4_err("install tests will fail if the install path has spaces: '${CMAKE_INSTALL_PREFIX}' : ... ${has_spaces}")
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
                c4_err("not implemented")
            endif()
        endif()
    elseif(ANDROID OR IOS OR WINCE OR WINDOWS_PHONE)
        c4_err("not implemented")
    elseif(IOS)
        c4_err("not implemented")
    elseif(UNIX)
        if(CMAKE_GENERATOR_PLATFORM OR CMAKE_VS_PLATFORM_NAME)
            set(arch "-DCMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}" "-DCMAKE_VS_PLATFORM_NAME=${CMAKE_VS_PLATFORM_NAME}")
        else()
            if(CMAKE_SYSTEM_PROCESSOR STREQUAL aarch64)
            else()
                if(CMAKE_SIZEOF_VOID_P EQUAL 8)
                    set(arch "-DCMAKE_CXX_FLAGS=-m64")
                elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
                    set(arch "-DCMAKE_CXX_FLAGS=-m32")
                else()
                    c4_err("not implemented")
                endif()
            endif()
        endif()
    endif()
    # generate the cmake script with the test content
    file(WRITE "${tsrc}" "
# run a command and check its return status
function(runcmd id)
    set(cmdout \"${tout}-\${id}.log\")
    message(STATUS \"Running command: \${ARGN}\")
    message(STATUS \"Running command: output goes to \${cmdout}\")
    execute_process(
        COMMAND \${ARGN}
        RESULT_VARIABLE retval
        OUTPUT_FILE \"\${cmdout}\"
        ERROR_FILE \"\${cmdout}\"
        # COMMAND_ECHO STDOUT  # only available from cmake-3.15
    )
    message(STATUS \"Running command: exit status was \${retval}\")
    file(READ \"\${cmdout}\" output)
    if(\"\${cmdout}\" STREQUAL \"\")
        message(STATUS \"Running command: no output\")
    else()
        message(STATUS \"Running command: output:
--------------------
\${output}--------------------\")
    endif()
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

# remove any existing library install
if(EXISTS \"\${pfx}\")
    runcmd(0_rmdir \"\${cmk}\" -E remove_directory \"\${pfx}\")
else()
    message(STATUS \"does not exist: \${pfx}\")
endif()

# install the library
#runcmd(1_install_lib \"\${cmk}\" --install \"\${idir}\" ${cfg_opt})  # requires cmake>3.13 (at least)
runcmd(1_install_lib \"\${cmk}\" --build \"\${idir}\" ${cfg_opt} --target install)

# configure the client project
runcmd(2_config \"\${cmk}\" -S \"\${pdir}\" -B \"\${bdir}\" \"-DCMAKE_PREFIX_PATH=\${pfx}\" \"-DCMAKE_GENERATOR=${CMAKE_GENERATOR}\" ${arch} \"-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}\" \"-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}\")

# build the client project
runcmd(3_build \"\${cmk}\" --build \"\${bdir}\" ${cfg_opt})

# run the client executable
runcmd(4_install \"\${cmk}\" --build \"\${bdir}\" --target \"${pname}-run\" ${cfg_opt})
")
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
function(c4_setup_valgrind umbrella_option)
    if(UNIX AND (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Coverage"))
        if("${C4_VALGRIND}" STREQUAL "")
            option(C4_VALGRIND "enable valgrind tests (all subprojects)" ON)
        endif()
        if(${CMAKE_VERSION} VERSION_GREATER_EQUAL 3.22)
            cmake_policy(PUSH)
            cmake_policy(SET CMP0127 NEW)
        endif()
        cmake_dependent_option(${_c4_uprefix}VALGRIND "enable valgrind tests" ${C4_VALGRIND} ${umbrella_option} OFF)
        if(${CMAKE_VERSION} VERSION_GREATER_EQUAL 3.22)
            cmake_policy(POP)
        endif()
        if(${_c4_uprefix}VALGRIND)
            set(${_c4_uprefix}VALGRIND_OPTIONS "--gen-suppressions=all --error-exitcode=10101" CACHE STRING "options for valgrind tests")
        endif()
    endif()
endfunction(c4_setup_valgrind)


function(c4_add_valgrind target_name)
    _c4_handle_args(_ARGS ${ARGN}
      _ARGS0  # zero-value macro arguments
      _ARGS1  # one-value macro arguments
        WORKING_DIRECTORY
      _ARGSN  # multi-value macro arguments
        ARGS
    )
    #
    if(_WORKING_DIRECTORY)
        set(_WORKING_DIRECTORY WORKING_DIRECTORY ${_WORKING_DIRECTORY})
    endif()
    # @todo: consider doing this for valgrind:
    # http://stackoverflow.com/questions/40325957/how-do-i-add-valgrind-tests-to-my-cmake-test-target
    # for now we explicitly run it:
    if(${_c4_uprefix}VALGRIND)
        separate_arguments(_vg_opts UNIX_COMMAND "${${_c4_uprefix}VALGRIND_OPTIONS}")
        add_test(NAME ${target_name}-valgrind
            COMMAND valgrind ${_vg_opts} $<TARGET_FILE:${target_name}> ${_ARGS}
            ${_WORKING_DIRECTORY}
            COMMAND_EXPAND_LISTS)
    endif()
endfunction(c4_add_valgrind)


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

function(c4_setup_coverage)
    if(NOT ("${CMAKE_BUILD_TYPE}" STREQUAL "Coverage"))
        return()
    endif()
    #
    _c4_handle_args(_ARGS ${ARGN}
      _ARGS0  # zero-value macro arguments
      _ARGS1  # one-value macro arguments
      _ARGSN  # multi-value macro arguments
        COVFLAGS      # coverage compilation flags
        INCLUDE       # patterns to include in the coverage, relative to CMAKE_SOURCE_DIR
        EXCLUDE       # patterns to exclude in the coverage, relative to CMAKE_SOURCE_DIR
        EXCLUDE_ABS   # absolute paths to exclude in the coverage
        GENHTML_ARGS  # options to pass to genhtml
        LCOV_ARGS     # options to pass to lcov
    )
    # defaults for the macro arguments
    set(covflags "-g -O0 --coverage")
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
        set(covflags "${covflags} -fprofile-arcs -ftest-coverage -fno-inline -fno-inline-small-functions -fno-default-inline")
    endif()
    set(${_c4_uprefix}COVERAGE_FLAGS "${covflags}" CACHE STRING "coverage compilation flags")
    set(${_c4_uprefix}COVERAGE_LCOV_ARGS " " CACHE STRING "extra flags to pass to lcov")
    set(${_c4_uprefix}COVERAGE_GENHTML_ARGS "--title ${_c4_lcprefix} --demangle-cpp --sort --function-coverage --branch-coverage --prefix '${CMAKE_SOURCE_DIR}' --prefix '${CMAKE_BINARY_DIR}'" CACHE STRING "arguments to pass to genhtml" FORCE)
    set(${_c4_uprefix}COVERAGE_INCLUDE src CACHE STRING "relative paths to include in the coverage, relative to CMAKE_SOURCE_DIR")
    set(${_c4_uprefix}COVERAGE_EXCLUDE bm;build;extern;ext;src/c4/ext;test CACHE STRING "relative paths to exclude from the coverage, relative to CMAKE_SOURCE_DIR")
    set(${_c4_uprefix}COVERAGE_EXCLUDE_ABS /usr CACHE STRING "absolute paths to exclude from the coverage")
    option(${_c4_uprefix}COVERAGE_LCOV_IGNORE_ERR "suppress lcov errors" ON)
    option(${_c4_uprefix}COVERAGE_CODECOV "enable target to submit coverage to codecov.io" OFF)
    option(${_c4_uprefix}COVERAGE_COVERALLS "enable target to submit coverage to coveralls.io" OFF)
    #
    # get the arguments, or default them
    _c4_handle_arg(COVFLAGS ${${_c4_uprefix}COVERAGE_FLAGS})
    _c4_handle_arg(INCLUDE ${${_c4_uprefix}COVERAGE_INCLUDE})
    _c4_handle_arg(EXCLUDE ${${_c4_uprefix}COVERAGE_EXCLUDE})
    _c4_handle_arg(EXCLUDE_ABS ${${_c4_uprefix}COVERAGE_EXCLUDE_ABS} "${CMAKE_BINARY_DIR}")
    _c4_handle_arg(LCOV_ARGS "") # default to nothing
    _c4_handle_arg(GENHTML_ARGS ${${_c4_uprefix}COVERAGE_GENHTML_ARGS})
    #
    function(_c4cov_transform_filters var reldir)
        set(_filters)
        foreach(pat ${${var}})
            list(APPEND _filters "'${reldir}${pat}/*'")
        endforeach()
        set(${var} ${_filters} PARENT_SCOPE)
    endfunction()
    _c4cov_transform_filters(_INCLUDE "${CMAKE_SOURCE_DIR}/")
    _c4cov_transform_filters(_EXCLUDE "${CMAKE_SOURCE_DIR}/")
    _c4cov_transform_filters(_EXCLUDE_ABS "")
    #
    if("${CMAKE_CXX_COMPILER_ID}" MATCHES "(Apple)?[Cc]lang")
        if("${CMAKE_CXX_COMPILER_VERSION}" VERSION_LESS 3)
	    c4_err("coverage: clang version must be 3.0.0 or greater")
        endif()
    elseif(NOT CMAKE_COMPILER_IS_GNUCXX)
        c4_err("coverage: compiler is not GNUCXX")
    endif()
    #
    find_program(GCOV gcov)
    find_program(LCOV lcov)
    find_program(GENHTML genhtml)
    find_program(CTEST ctest)
    if(GCOV)
        execute_process(COMMAND ${GCOV} --version OUTPUT_VARIABLE rv)
        string(REPLACE "\n" ";" rv "${rv}")
        list(GET rv 0 GCOV_VERSION)
    endif()
    if(LCOV)
        execute_process(COMMAND ${LCOV} --version OUTPUT_VARIABLE rv)
        string(REPLACE "\n" "" LCOV_VERSION "${rv}")
    endif()
    if(GENHTML)
        execute_process(COMMAND ${GENHTML} --version OUTPUT_VARIABLE rv)
        string(REPLACE "\n" "" GENHTML_VERSION "${rv}")
    endif()
    add_configuration_type(Coverage
        DEFAULT_FROM DEBUG
        C_FLAGS ${_COVFLAGS}
        CXX_FLAGS ${_COVFLAGS}
        )
    #
    c4_dbg("adding coverage targets")
    #
    set(sd "${CMAKE_SOURCE_DIR}")
    set(bd "${CMAKE_BINARY_DIR}")
    set(coverage_result ${bd}/lcov/index.html)
    set(lcov_result ${bd}/coverage3-final_filtered.lcov)
    set(lcov_flags "${_LCOV_ARGS} ${${_c4_uprefix}COVERAGE_LCOV_ARGS}")
    #string(APPEND lcov_flags " -v -v --debug")
    if(${_c4_uprefix}COVERAGE_LCOV_IGNORE_ERR)
        string(APPEND lcov_flags " --ignore-errors gcov,gcov")
        # this is only available in recent lcov versions:
        #string(APPEND lcov_flags " --ignore-errors mismatch,mismatch")
        #string(APPEND lcov_flags " --ignore-errors unused,unused")
    endif()
    c4_log("Coverage:
    gcov: ${GCOV}   ${GCOV_VERSION}
    lcov: ${LCOV}   ${LCOV_VERSION}
    genhtml: ${GENHTML}   ${GENHTML_VERSION}
    ctest: ${CTEST}
    gcc coverage flags: ${_COVFLAGS}
    lcov args: ${lcov_flags}
    genhtml args: ${_GENHTML_ARGS}")
    if(NOT (GCOV AND LCOV AND GENHTML AND CTEST))
        c4_err("Coverage tools not available")
    endif()
    #
    separate_arguments(lcov_flags NATIVE_COMMAND ${lcov_flags})
    separate_arguments(_GENHTML_ARGS NATIVE_COMMAND ${_GENHTML_ARGS})
    add_custom_target(${_c4_lprefix}coverage
        BYPRODUCTS ${coverage_result} ${lcov_result}
        COMMAND echo "cd ${CMAKE_BINARY_DIR}"
        COMMAND ${LCOV} ${lcov_flags} -q --zerocounters --directory .
        COMMAND ${LCOV} ${lcov_flags} -q --no-external --capture --base-directory "${sd}" --directory . --output-file ${bd}/coverage0-before.lcov --initial
        COMMAND ${CMAKE_COMMAND} --build . --target ${_c4_lprefix}test-run || echo "Failed running the tests. Proceeding with coverage, but results may be affected or even empty."
        COMMAND ${LCOV} ${lcov_flags} -q --no-external --capture --base-directory "${sd}" --directory . --output-file ${bd}/coverage1-after.lcov
        COMMAND ${LCOV} ${lcov_flags} -q --add-tracefile ${bd}/coverage0-before.lcov --add-tracefile ${bd}/coverage1-after.lcov --output-file ${bd}/coverage2-final.lcov
        COMMAND ${LCOV} ${lcov_flags} -q --remove ${bd}/coverage2-final.lcov ${_EXCLUDE} ${EXCLUDE_ABS} --output-file ${bd}/coverage3-final_filtered.lcov
        COMMAND ${GENHTML} ${lcov_result} -o ${bd}/lcov ${_GENHTML_ARGS}
        COMMAND echo "Coverage report: ${coverage_result}"
        DEPENDS ${_c4_lprefix}test-build
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "${_c4_prefix} coverage: LCOV report at ${coverage_result}"
        #VERBATIM
        )
    #
    if(${_c4_uprefix}COVERAGE_CODECOV)
        set(_subm ${_c4_lprefix}coverage-submit-codecov)
        _c4cov_get_service_token(codecov _token)
        if(NOT ("${_token}" STREQUAL ""))
            set(_token -t "${_token}")
        endif()
        set(_silent_codecov)
        if(${_c4_uprefix}COVERAGE_CODECOV_SILENT)
            set(_silent_codecov >${CMAKE_BINARY_DIR}/codecov.log 2>&1)
        endif()
        #
        c4_log("coverage: enabling submission of results to https://codecov.io: ${_subm}")
        set(submitcc "${CMAKE_BINARY_DIR}/submit_codecov.sh")
        c4_download_file("https://codecov.io/bash" "${submitcc}")
        set(submit_cmd bash ${submitcc} -Z ${_token} -X gcov -X gcovout -p ${CMAKE_SOURCE_DIR} -f ${lcov_result} ${_silent_codecov})
        string(REPLACE ";" " " submit_cmd_str "${submit_cmd}")
        add_custom_target(${_subm}
            SOURCES ${lcov_result}
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            COMMAND echo "cd ${CMAKE_BINARY_DIR} && ${submit_cmd_str}"
            COMMAND ${submit_cmd}
            VERBATIM
            COMMENT "${_c4_lcprefix} coverage: submit to codecov"
            )
        c4_add_umbrella_target(coverage-submit-codecov coverage-submit)  # uses the current prefix
    endif()
    #
    if(${_c4_uprefix}COVERAGE_COVERALLS)
        set(_subm ${_c4_lprefix}coverage-submit-coveralls)
        _c4cov_get_service_token(coveralls _token)
        if(NOT ("${_token}" STREQUAL ""))
            set(_token --repo-token "${_token}")
        endif()
        set(_silent_coveralls)
        if(${_c4_uprefix}COVERAGE_COVERALLS_SILENT)
            set(_silent_coveralls >${CMAKE_BINARY_DIR}/coveralls.log 2>&1)
        endif()
        #
        c4_log("coverage: enabling submission of results to https://coveralls.io: ${_subm}")
        set(submit_cmd coveralls ${_token} --build-root ${CMAKE_BINARY_DIR} --root ${CMAKE_SOURCE_DIR} --no-gcov --lcov-file ${lcov_result} ${_silent_coveralls})
        string(REPLACE ";" " " submit_cmd_str "${submit_cmd}")
        add_custom_target(${_subm}
            SOURCES ${lcov_result}
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            COMMAND echo "cd ${CMAKE_BINARY_DIR} && ${submit_cmd_str}"
            COMMAND ${submit_cmd}
            VERBATIM
            COMMENT "${_c4_lcprefix} coverage: submit to coveralls"
            )
        c4_add_umbrella_target(coverage-submit-coveralls coverage-submit)  # uses the current prefix
    endif()
endfunction(c4_setup_coverage)


# 1. try cmake or environment variables
# 2. try local file
function(_c4cov_get_service_token service out)
    # try cmake var
    string(TOUPPER ${service} uservice)
    c4_get_from_first_of(token COVERAGE_${uservice}_TOKEN ENV)
    if(NOT ("${token}" STREQUAL ""))
        c4_dbg("${service}: found token from variable: ${token}")
    else()
        # try local file
        set(service_token_file ${CMAKE_SOURCE_DIR}/.ci/${service}.token)
        if(EXISTS ${service_token_file})
            file(READ ${service_token_file} token)
            c4_dbg("found token file for ${service} coverage report: ${service_token_file}")
        else()
            c4_dbg("could not find token for ${service} coverage report")
        endif()
    endif()
    set(${out} ${token} PARENT_SCOPE)
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

function(c4_add_umbrella_target target umbrella_target)
    _c4_handle_args(_ARGS ${ARGN}
      # zero-value macro arguments
      _ARGS0
        ALWAYS  # Add the umbrella target even if this is the only one under it.
                # The default behavior is to add the umbrella target only if
                # there is more than one target under it.
      # one-value macro arguments
      _ARGS1
        PREFIX  # The project prefix. Defaults to ${_c4_lprefix}
      # multi-value macro arguments
      _ARGSN
        ARGS    # more args to add_custom_target()
    )
    if(NOT _PREFIX)
        set(_PREFIX "${_c4_lprefix}")
    endif()
    set(t ${_PREFIX}${target})
    set(ut ${_PREFIX}${umbrella_target})
    # if the umbrella target already exists, just add the dependency
    if(TARGET ${ut})
        add_dependencies(${ut} ${t})
    else()
        if(_ALWAYS)
            add_custom_target(${ut} ${_ARGS})
            add_dependencies(${ut} ${t})
        else()
            # check if there is more than one under the same umbrella
            c4_get_proj_prop(${ut}_subtargets sub)
            if(sub)
                add_custom_target(${ut} ${_ARGS})
                add_dependencies(${ut} ${sub})
                add_dependencies(${ut} ${t})
            else()
                c4_set_proj_prop(${ut}_subtargets ${t})
            endif()
        endif()
    endif()
endfunction()



function(c4_download_file url dstpath)
    c4_dbg("downloading file: ${url} ---> ${dstpath}")
    get_filename_component(abspath ${dstpath} ABSOLUTE)
    if(NOT EXISTS ${abspath})
        c4_dbg("downloading file: does not exist: ${dstpath}")
        file(DOWNLOAD ${url} ${abspath} LOG dl_log STATUS status ${ARGN})
        if((NOT (status EQUAL 0)) OR (NOT EXISTS ${abspath}))
            c4_err("error downloading file: ${url} -> ${abspath}:\n${dl_log}")
        endif()
    endif()
endfunction()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
function(c4_setup_benchmarking)
    c4_log("enabling benchmarks: to build, ${_c4_lprefix}bm-build")
    c4_log("enabling benchmarks: to run, ${_c4_lprefix}bm-run")
    # umbrella target for building test binaries
    add_custom_target(${_c4_lprefix}bm-build)
    # umbrella target for running benchmarks
    add_custom_target(${_c4_lprefix}bm-run
        ${CMAKE_COMMAND} -E echo CWD=${CMAKE_CURRENT_BINARY_DIR}
        DEPENDS ${_c4_lprefix}bm-build
        )
    if(NOT TARGET bm-run)
        add_custom_target(bm-run)
        add_custom_target(bm-build)
    endif()
    add_dependencies(bm-run ${_c4_lprefix}bm-run)
    add_dependencies(bm-build ${_c4_lprefix}bm-build)
    _c4_set_target_folder(${_c4_lprefix}bm-run bm)
    _c4_set_target_folder(${_c4_lprefix}bm-build bm)
    _c4_set_target_folder(bm-build "/bm")
    _c4_set_target_folder(bm-run "/bm")
    # download google benchmark
    if(NOT TARGET benchmark)
        set(with_exceptions OFF)
        if(MSVC)
            set(with_exceptions ON)
        endif()
        c4_import_remote_proj(googlebenchmark ${CMAKE_CURRENT_BINARY_DIR}/ext/googlebenchmark
          REMOTE
            GIT_REPOSITORY https://github.com/google/benchmark.git
            GIT_TAG main
            GIT_SHALLOW ON
          OVERRIDE
            BENCHMARK_ENABLE_TESTING OFF
            BENCHMARK_ENABLE_EXCEPTIONS ${with_exceptions}
            BENCHMARK_ENABLE_LTO OFF
          SET_FOLDER_TARGETS ext benchmark benchmark_main
          EXCLUDE_FROM_ALL
          )
        #
        if((CMAKE_CXX_COMPILER_ID STREQUAL GNU) OR (CMAKE_COMPILER_IS_GNUCC))
            target_compile_options(benchmark PRIVATE -Wno-deprecated-declarations)
            target_compile_options(benchmark PRIVATE -Wno-unused-const-variable)
            target_compile_options(benchmark PRIVATE -Wno-restrict)
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
    endif()
endfunction()


function(c4_add_benchmark_cmd casename)
    add_custom_target(${casename}
        COMMAND ${ARGN}
        VERBATIM
        COMMENT "${_c4_prefix}: running benchmark ${casename}: ${ARGN}")
    add_dependencies(${_c4_lprefix}bm-build ${casename})
    _c4_set_target_folder(${casename} bm)
endfunction()


# assumes this is a googlebenchmark target, and that multiple
# benchmarks are defined from it
function(c4_add_target_benchmark target casename)
    set(opt0arg
    )
    set(opt1arg
        WORKDIR # working directory
        FILTER  # benchmark patterns to filter
        UMBRELLA_TARGET
        RESULTS_FILE
    )
    set(optnarg
        ARGS
    )
    cmake_parse_arguments("" "${opt0arg}" "${opt1arg}" "${optnarg}" ${ARGN})
    #
    set(name "${target}-${casename}")
    set(rdir "${CMAKE_CURRENT_BINARY_DIR}/bm-results")
    set(rfile "${rdir}/${name}.json")
    if(_RESULTS_FILE)
        set(${_RESULTS_FILE} "${rfile}" PARENT_SCOPE)
    endif()
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
        ${args_fwd}
        OUTPUT_FILE ${rfile})
    if(_UMBRELLA_TARGET)
        add_dependencies(${_UMBRELLA_TARGET} "${name}")
    endif()
endfunction()


function(c4_add_benchmark target casename work_dir comment)
    set(opt0arg
    )
    set(opt1arg
        OUTPUT_FILE
    )
    set(optnarg
    )
    cmake_parse_arguments("" "${opt0arg}" "${opt1arg}" "${optnarg}" ${ARGN})
    if(NOT TARGET ${target})
        c4_err("target ${target} does not exist...")
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
    if(_OUTPUT_FILE)
        set(_OUTPUT_FILE BYPRODUCTS ${_OUTPUT_FILE})
        set(_OUTPUT_FILE) # otherwise the benchmarks run everytime when building depending targets
    endif()
    add_custom_target(${casename}
        ${cpupow_before}
        # this is useful to show the target file (you cannot echo generator variables)
        #COMMAND ${CMAKE_COMMAND} -E echo "target file = $<TARGET_FILE:${target}>"
        COMMAND ${CMAKE_COMMAND} -E echo "${exe} ${ARGN}"
        COMMAND "${exe}" ${ARGN}
        ${cpupow_after}
        VERBATIM
        ${_OUTPUT_FILE}
        WORKING_DIRECTORY "${work_dir}"
        DEPENDS ${target}
        COMMENT "${_c4_lcprefix}: running benchmark ${target}, case ${casename}: ${comment}"
        )
    add_dependencies(${_c4_lprefix}bm-build ${target})
    add_dependencies(${_c4_lprefix}bm-run ${casename})
    _c4_set_target_folder(${casename} bm/run)
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

function(_c4cat_filter_additional_exts in out)
    _c4cat_filter_extensions("${in}" "${C4_ADD_EXTS}" l)
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
        if("${ext}" STREQUAL "${e}")
            set(${out} TRUE PARENT_SCOPE)
            return()
        endif()
    endforeach()
    set(${out} FALSE PARENT_SCOPE)
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
