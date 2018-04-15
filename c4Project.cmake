if(NOT _c4_project_included)
set(_c4_project_included ON)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

include(ConfigurationTypes)
include(CreateSourceGroup)
include(SanitizeTarget)
include(StaticAnalysis)
include(PrintVar)
include(c4CatSources)


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
macro(_c4_handle_prefix prefix)
    string(TOUPPER "${prefix}" ucprefix)
    string(TOLOWER "${prefix}" lcprefix)
    set(uprefix ${ucprefix})
    set(lprefix ${lcprefix})
    if(uprefix)
        set(uprefix "${uprefix}_")
    endif()
    if(lprefix)
        set(lprefix "${lprefix}-")
    endif()
endmacro(_c4_handle_prefix)

macro(_show_pfx_vars)
    print_var(prefix)
    print_var(ucprefix)
    print_var(lcprefix)
    print_var(uprefix)
    print_var(lprefix)
endmacro()


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

function(c4_declare_project prefix)
    _c4_handle_prefix(${prefix})
    option(${uprefix}DEV "enable development targets: tests, benchmarks, sanitize, static analysis, coverage" OFF)
    cmake_dependent_option(${uprefix}BUILD_TESTS "build unit tests" ON ${uprefix}DEV OFF)
    cmake_dependent_option(${uprefix}BUILD_BENCHMARKS "build benchmarks" ON ${uprefix}DEV OFF)
    c4_setup_coverage(${ucprefix})
    c4_setup_valgrind(${ucprefix} ${uprefix}DEV)
    setup_sanitize(${ucprefix} ${uprefix}DEV)
    setup_static_analysis(${ucprefix} ${uprefix}DEV)

    # these are default compilation flags
    set(f "")
    if(NOT MSVC)
        set(f "${f} -std=c++11")
    endif()
    set(${uprefix}CXX_FLAGS ${f} CACHE STRING "compilation flags")

    # these are optional compilation flags
    cmake_dependent_option(${uprefix}PEDANTIC "Compile in pedantic mode" ON ${uprefix}DEV OFF)
    cmake_dependent_option(${uprefix}WERROR "Compile with warnings as errors" ON ${uprefix}DEV OFF)
    cmake_dependent_option(${uprefix}STRICT_ALIASING "Enable strict aliasing" ON ${uprefix}DEV OFF)

    if(${uprefix}STRICT_ALIASING)
        if(NOT MSVC)
            set(of "${of} -fstrict-aliasing")
        endif()
    endif()
    if(${uprefix}PEDANTIC)
        if(MSVC)
            set(of "${of} /W4")
            # silence MSVC pedantic error on googletest's use of tr1: https://github.com/google/googletest/issues/1111
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /D_SILENCE_TR1_NAMESPACE_DEPRECATION_WARNING")
        else()
            set(of "${of} -Wall -Wextra -Wshadow -pedantic -Wfloat-equal -fstrict-aliasing")
        endif()
    endif()
    if(${uprefix}WERROR)
        if(MSVC)
            set(of "${of} /WX")
        else()
            set(of "${of} -Werror -pedantic-errors")
        endif()
    endif()
    set(${uprefix}CXX_FLAGS "${${uprefix}CXX_FLAGS} ${of}")

endfunction(c4_declare_project)


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# type can be one of:
#  DIR:  the module is located in the given directory name and
#        will be added via add_subdirectory()
#  REMOTE: the module is located in a remote repo/url
#          and will be added via c4_import_remote_proj()
function(c4_require_module prefix module_name type)
    _c4_handle_prefix(${prefix})
    list(APPEND _${uprefix}_deps ${module_name})
    set(_${uprefix}_deps ${_${uprefix}_deps} PARENT_SCOPE)
    if(NOT _${module_name}_available)
        set(_${module_name}_available ON PARENT_SCOPE)
        if("${type}" STREQUAL "REMOTE")
            set(_r ${CMAKE_CURRENT_BINARY_DIR}/modules/${module_name}) # root
            c4_import_remote_proj(${prefix} ${module_name} ${_r} ${ARGN})
            set(${uprefix}${module_name}_SRC_DIR ${_r}/src PARENT_SCOPE)
            set(${uprefix}${module_name}_BIN_DIR ${_r}/build PARENT_SCOPE)
        elseif("${type}" STREQUAL "SUBDIRECTORY")
            set(_r ${CMAKE_CURRENT_BINARY_DIR}/modules/${module_name}) # root
            add_subdirectory(${ARGN} ${_r}/build)
            set(${uprefix}${module_name}_SRC_DIR ${ARGN} PARENT_SCOPE)
            set(${uprefix}${module_name}_BIN_DIR ${_r}/build PARENT_SCOPE)
        else()
            message(FATAL_ERROR "module type must be either REMOTE or SUBDIRECTORY")
        endif()
    endif()
endfunction(c4_require_module)


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

function(c4_add_library prefix name)
    c4_add_target(${prefix} ${name} LIBRARY ${ARGN})
endfunction(c4_add_library)

function(c4_add_executable prefix name)
    c4_add_target(${prefix} ${name} EXECUTABLE ${ARGN})
endfunction(c4_add_executable)


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

function(c4_set_default var val)
    if(${var} STREQUAL "")
        set(${var} ${val} PARENT_SCOPE)
    endif()
endfunction()

function(c4_set_cache_default var val)
    if(${var} STREQUAL "")
        set(${var} ${val} ${ARGN})
    endif()
endfunction()

# document this variable
c4_set_default(BUILD_LIBRARY_TYPE static)
set(BUILD_LIBRARY_TYPE "${BUILD_LIBRARY_TYPE}" CACHE STRING "specify how to build libraries: must be one of default,scu,scu_iface,headers,single_header.
default: defaults to BUILD_SHARED_LIBS behaviour
scu: concatenate all compilation unit files into a single compilation unit, compile it as if using LTO
scu_iface: concatenate all compilation unit files into a single compilation unit, expose it as the target's public interface to be consumed by clients
headers: concatenate all compilation unit files into a single header file
single_header: concatenate all files into a single header file.

This variable overrides BUILD_SHARED_LIBS behaviour.")

# document this variable
c4_set_default(BUILD_EXECUTABLE_TYPE default)
set(BUILD_EXECUTABLE_TYPE "${BUILD_EXECUTABLE_TYPE}" CACHE STRING "specify how to build executables: must be one of mcu,scu.
default: multiple compilation units (traditional compiler behaviour)
scu: single compilation unit")

set(BUILD_HDR_EXTS "h;hpp;hh;h++;hxx" CACHE STRING "list of header extensions for determining which files are headers")
set(BUILD_SRC_EXTS "c;cpp;cc;c++;cxx;cu" CACHE STRING "list of compilation unit extensions for determining which files are sources")
set(BUILD_SRCOUT_EXT "cpp" CACHE STRING "the extension of the output source files resulting from concatenation")
set(BUILD_HDROUT_EXT "hpp" CACHE STRING "the extension of the output header files resulting from concatenation")

function(_c4cat_get_outname prefix target id ext out)
    _c4_handle_prefix(${prefix})
    if(lcprefix STREQUAL target)
        set(p "${target}")
    else()
        set(p "${lcprefix}.${target}")
    endif()
    set(${out} "${CMAKE_CURRENT_BINARY_DIR}/${p}.${id}.${ext}" PARENT_SCOPE)
endfunction()

function(_c4cat_filter_srcs in out)
    _c4cat_filter_extensions("${in}" "${BUILD_SRC_EXTS}" l)
    set(${out} ${l} PARENT_SCOPE)
endfunction()

function(_c4cat_filter_hdrs in out)
    _c4cat_filter_extensions("${in}" "${BUILD_HDR_EXTS}" l)
    set(${out} ${l} PARENT_SCOPE)
endfunction()

function(_c4cat_filter_srcs_hdrs in out)
    _c4cat_filter_extensions("${in}" "${BUILD_HDR_EXTS};${BUILD_SRC_EXTS}" l)
    set(${out} ${l} PARENT_SCOPE)
endfunction()

function(_c4cat_filter_extensions in filter out)
    set(l)
    foreach(fn ${in})
        _c4cat_get_file_ext(${fn} ext)
        _c4cat_one_of(${ext} "${filter}" yes)
        if(${yes})
            list(APPEND l ${fn})
        endif()
    endforeach()
    set(${out} ${l} PARENT_SCOPE)
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

# example: c4_add_target(RYML ryml LIBRARY SOURCES ${SRC})
function(c4_add_target prefix name)
    #message(STATUS "${prefix}: adding target: ${name}: ${ARGN}")
    _c4_handle_prefix(${prefix})
    set(options0arg
        EXECUTABLE
        LIBRARY
        SANITIZE
    )
    set(options1arg
        FOLDER
        SANITIZERS  # outputs the list of sanitize targets in this var
    )
    set(optionsnarg
        SOURCES
        HEADERS
        INC_DIRS PRIVATE_INC_DIRS
        LIBS PRIVATE_LIBS
        MORE_ARGS
    )
    cmake_parse_arguments(_c4al "${options0arg}" "${options1arg}" "${optionsnarg}" ${ARGN})
    if(${_c4al_LIBRARY})
        set(_what LIBRARY)
    elseif(${_c4al_EXECUTABLE})
        set(_what EXECUTABLE)
    endif()

    c4_to_full_path("${_c4al_SOURCES}" fullsrc)
    set(_c4al_SOURCES "${fullsrc}")

    create_source_group("" "${CMAKE_CURRENT_SOURCE_DIR}" "${_c4al_SOURCES}")

    if(NOT ${uprefix}SANITIZE_ONLY)
        if(${_c4al_EXECUTABLE})
            if(BUILD_EXECUTABLE_TYPE STREQUAL "scu")
                _c4cat_get_outname(${prefix} ${name} "all" ${BUILD_SRCOUT_EXT} out)
                c4_cat_sources(${prefix} "${l}" "${out}")
                add_executable(${name} ${out} ${_c4al_MORE_ARGS})
                add_dependencies(${name} ${out})
                add_dependencies(${name} ${lprefix}cat)
            else()
                add_executable(${name} ${_c4al_SOURCES} ${_c4al_MORE_ARGS})
            endif()
            set(tgt_type PUBLIC)
            set(compiled_target ON)
        elseif(${_c4al_LIBRARY})

            # https://rix0r.nl/blog/2015/08/13/cmake-guide/
            # https://steveire.wordpress.com/2016/08/09/opt-in-header-only-libraries-with-cmake/
            if(BUILD_LIBRARY_TYPE STREQUAL "headers")
                # header-only library - cat sources to a header file, leave other headers as is
                _c4cat_filter_srcs("${_c4al_SOURCES}" c)
                _c4cat_filter_hdrs("${_c4al_SOURCES}" h)
                _c4cat_get_outname(${prefix} ${name} "src" ${BUILD_HDROUT_EXT} out)
                c4_cat_sources(${prefix} "${c}" "${out}")
                add_library(${name} INTERFACE)
                add_dependencies(${name} ${out})
                add_dependencies(${name} ${lprefix}cat)
                set(tgt_type INTERFACE)
                target_sources(${name} INTERFACE $<INSTALL_INTERFACE:${h};${out}> $<BUILD_INTERFACE:${h};${out}>)
                target_compile_definitions(${name} INTERFACE ${uprefix}HEADER_ONLY)
                list(APPEND _c4al_INC_DIRS  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>)

            elseif(BUILD_LIBRARY_TYPE STREQUAL "single_header")
                # header-only library, in a single header
                _c4cat_get_outname(${prefix} ${name} "all" ${BUILD_HDROUT_EXT} out)
                _c4cat_filter_srcs_hdrs("${_c4al_SOURCES}" ch)
                c4_cat_sources(${prefix} "${ch}" "${out}")
                add_library(${name} INTERFACE)
                add_dependencies(${name} ${out})
                add_dependencies(${name} ${lprefix}cat)
                set(tgt_type INTERFACE)
                target_sources(${name} INTERFACE $<INSTALL_INTERFACE:${out}> $<BUILD_INTERFACE:${out}>)
                target_compile_definitions(${name} INTERFACE ${uprefix}SINGLE_HEADER)
                list(APPEND _c4al_INC_DIRS  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>)

            elseif(BUILD_LIBRARY_TYPE STREQUAL "scu_iface")
                # single compilation unit, source (.cpp) file exposed as interface
                _c4cat_filter_srcs("${_c4al_SOURCES}" c)
                _c4cat_get_outname(${prefix} ${name} "scu" ${BUILD_SRCOUT_EXT} scu)
                c4_cat_sources(${prefix} "${c}" "${scu}")
                add_library(${name} INTERFACE)
                add_dependencies(${name} ${scu})
                add_dependencies(${name} ${lprefix}cat)
                set(tgt_type INTERFACE)
                target_sources(${name} INTERFACE $<INSTALL_INTERFACE:${scu}> $<BUILD_INTERFACE:${scu}>)

            elseif(BUILD_LIBRARY_TYPE STREQUAL "scu")
                # single compilation unit, as if using LTO
                _c4cat_filter_srcs("${_c4al_SOURCES}" c)
                _c4cat_get_outname(${prefix} ${name} "scu" ${BUILD_SRCOUT_EXT} scu)
                c4_cat_sources(${prefix} "${c}" "${scu}")
                add_library(${name} ${scu} ${_c4al_MORE_ARGS})
                add_dependencies(${name} ${scu})
                add_dependencies(${name} ${lprefix}cat)
                set(tgt_type PUBLIC)
                #target_sources(${name} PUBLIC ${_c4al_SOURCES})

            else()
                # obey BUILD_SHARED_LIBS (ie, either static or shared library)
                add_library(${name} ${_c4al_SOURCES} ${_c4al_MORE_ARGS})
                set(tgt_type PUBLIC)
            endif()
        endif()
        if(tgt_type STREQUAL INTERFACE)
            set(compiled_target OFF)
        else()
            set(compiled_target ON)
        endif()
        if(_c4al_INC_DIRS)
            target_include_directories(${name} ${tgt_type} ${_c4al_INC_DIRS})
        endif()
        if(_c4al_PRIVATE_INC_DIRS)
            target_include_directories(${name} PRIVATE ${_c4al_PRIVATE_INC_DIRS})
        endif()
        if(_c4al_LIBS)
            target_link_libraries(${name} ${tgt_type} ${_c4al_LIBS})
        endif()
        if(_c4al_PRIVATE_LIBS)
            target_link_libraries(${name} PRIVATE ${_c4al_PRIVATE_LIBS})
        endif()
        if(compiled_target)
            if(_c4al_FOLDER)
                set_target_properties(${name} PROPERTIES FOLDER "${_c4al_FOLDER}")
            endif()
            if(${uprefix}CXX_FLAGS OR ${uprefix}C_FLAGS)
                #print_var(${uprefix}CXX_FLAGS)
                set_target_properties(${name} PROPERTIES COMPILE_FLAGS ${${uprefix}CXX_FLAGS} ${${uprefix}C_FLAGS})
            endif()
            if(${uprefix}LINT)
                static_analysis_target(${ucprefix} ${name} "${_c4al_FOLDER}" lint_targets)
            endif()
        endif()
    endif()

    if(compiled_target)
        if(_c4al_SANITIZE OR ${uprefix}SANITIZE)
            sanitize_target(${name} ${lcprefix}
                ${_what}   # LIBRARY or EXECUTABLE
                SOURCES ${_c4al_SOURCES}
                INC_DIRS ${_c4al_INC_DIRS}
                LIBS ${_c4al_LIBS}
                OUTPUT_TARGET_NAMES san_targets
                FOLDER "${_c4al_FOLDER}"
                )
        endif()

        if(NOT ${uprefix}SANITIZE_ONLY)
            list(INSERT san_targets 0 ${name})
        endif()

        if(_c4al_SANITIZERS)
            set(${_c4al_SANITIZERS} ${san_targets} PARENT_SCOPE)
        endif()
    endif()

endfunction() # add_target


# TODO
function(c4_install_library prefix name)
    install(DIRECTORY
        example_lib/library
        DESTINATION
        include/example_lib
        )

    # install and export the library
    install(FILES
        example_lib/library.hpp
        example_lib/api.hpp
        DESTINATION
        include/example_lib
        )
    install(TARGETS ${name}
        EXPORT ${name}_targets
        RUNTIME DESTINATION bin
        ARCHIVE DESTINATION lib
        LIBRARY DESTINATION lib
        INCLUDES DESTINATION include
        )
    install(EXPORT ${name}_targets
        NAMESPACE ${name}::
        DESTINATION lib/cmake/${name}
        )
    install(FILES example_lib-config.cmake
        DESTINATION lib/cmake/${name}
        )
endfunction()

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

function(c4_setup_sanitize prefix initial_value)
    setup_sanitize(${prefix} ${initial_value})
endfunction(c4_setup_sanitize)

function(c4_setup_static_analysis prefix initial_value)
    setup_static_analysis(${prefix} ${initial_value})
endfunction(c4_setup_static_analysis)


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# download external libs while running cmake:
# https://crascit.com/2015/07/25/cmake-gtest/
# (via https://stackoverflow.com/questions/15175318/cmake-how-to-build-external-projects-and-include-their-targets)
#
# to specify url, repo, tag, or branch, pass the needed arguments
# after dir
function(c4_import_remote_proj prefix name dir)
    if(NOT EXISTS ${dir}/dl/CMakeLists.txt)
        _c4_handle_prefix(${prefix})
        message(STATUS "${lcprefix}: downloading remote project ${name}...")
        file(WRITE ${dir}/dl/CMakeLists.txt "
cmake_minimum_required(VERSION 2.8.2)
project(${lcprefix}-download-${name} NONE)

# this project only downloads ${name}
# (ie, no configure, build or install step)
include(ExternalProject)

ExternalProject_Add(${name}-dl
    ${ARGN}
    SOURCE_DIR \"${dir}/src\"
    BINARY_DIR \"${dir}/build\"
    CONFIGURE_COMMAND \"\"
    BUILD_COMMAND \"\"
    INSTALL_COMMAND \"\"
    TEST_COMMAND \"\"
)
")
        execute_process(COMMAND ${CMAKE_COMMAND} -G "${CMAKE_GENERATOR}" . WORKING_DIRECTORY ${dir}/dl)
        execute_process(COMMAND ${CMAKE_COMMAND} --build . WORKING_DIRECTORY ${dir}/dl)
    endif()
    add_subdirectory(${dir}/src ${dir}/build)
endfunction()

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
function(c4_setup_testing prefix initial_value)
    if(initial_value)
        _c4_handle_prefix(${prefix})
        message(STATUS "${lcprefix}: enabling tests")
        # umbrella target for building test binaries
        add_custom_target(${lprefix}test-build)
        set_target_properties(${lprefix}test-build PROPERTIES FOLDER ${lprefix}test)
        # umbrella target for running tests
        add_custom_target(${lprefix}test
            ${CMAKE_COMMAND} -E echo CWD=${CMAKE_BINARY_DIR}
            COMMAND ${CMAKE_COMMAND} -E echo CMD=${CMAKE_CTEST_COMMAND} -C $<CONFIG>
            COMMAND ${CMAKE_COMMAND} -E echo ----------------------------------
            COMMAND ${CMAKE_COMMAND} -E env CTEST_OUTPUT_ON_FAILURE=1 ${CMAKE_CTEST_COMMAND} ${${uprefix}CTEST_OPTIONS} -C $<CONFIG>
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            DEPENDS ${lprefix}test-build
            )
        set_target_properties(${lprefix}test PROPERTIES FOLDER ${lprefix}test)

        set(BUILD_GTEST ON CACHE BOOL "" FORCE)
        set(BUILD_GMOCK OFF CACHE BOOL "" FORCE)
        set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
        set(gtest_build_samples OFF CACHE BOOL "" FORCE)
        set(gtest_build_tests OFF CACHE BOOL "" FORCE)
        if(MSVC)
            # silence MSVC pedantic error on googletest's use of tr1: https://github.com/google/googletest/issues/1111
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /D_SILENCE_TR1_NAMESPACE_DEPRECATION_WARNING")
        endif()
        c4_import_remote_proj(${prefix} gtest ${CMAKE_CURRENT_BINARY_DIR}/extern/gtest
            GIT_REPOSITORY https://github.com/google/googletest.git
            GIT_TAG release-1.8.0
            )
    endif()
endfunction(c4_setup_testing)


function(c4_add_test prefix target)
    _c4_handle_prefix(${prefix})
    if(NOT ${uprefix}SANITIZE_ONLY)
        add_test(NAME ${target}-run COMMAND $<TARGET_FILE:${target}>)
    endif()
    if(NOT ${CMAKE_BUILD_TYPE} STREQUAL "Coverage")
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
            add_dependencies(${lprefix}test-build ${target}-all)
            set_target_properties(${target}-all PROPERTIES FOLDER ${lprefix}test/${target})
        else()
            add_dependencies(${lprefix}test-build ${target})
        endif()
    else()
        add_dependencies(${lprefix}test-build ${target})
        return()
    endif()
    if(sanitized_targets)
        foreach(s asan msan tsan ubsan)
            set(t ${target}-${s})
            if(TARGET ${t})
                add_dependencies(${target}-all ${t})
                sanitize_get_target_command($<TARGET_FILE:${t}> ${ucprefix} ${s} cmd)
                #message(STATUS "adding test: ${t}-run")
                add_test(NAME ${t}-run COMMAND ${cmd})
            endif()
        endforeach()
    endif()
    if(NOT ${uprefix}SANITIZE_ONLY)
        c4_add_valgrind(${prefix} ${target})
    endif()
    if(${uprefix}LINT)
        static_analysis_add_tests(${ucprefix} ${target})
    endif()
endfunction(c4_add_test)



#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
function(c4_setup_valgrind prefix umbrella_option)
    if(UNIX AND (NOT ${CMAKE_BUILD_TYPE} STREQUAL "Coverage"))
        _c4_handle_prefix(${prefix})
        cmake_dependent_option(${uprefix}VALGRIND "enable valgrind tests" ON ${umbrella_option} OFF)
        cmake_dependent_option(${uprefix}VALGRIND_SGCHECK "enable valgrind tests with the exp-sgcheck tool" OFF ${umbrella_option} OFF)
        set(${uprefix}VALGRIND_OPTIONS "--gen-suppressions=all --error-exitcode=10101" CACHE STRING "options for valgrind tests")
    endif()
endfunction(c4_setup_valgrind)


function(c4_add_valgrind prefix target_name)
    _c4_handle_prefix(${prefix})
    # @todo: consider doing this for valgrind:
    # http://stackoverflow.com/questions/40325957/how-do-i-add-valgrind-tests-to-my-cmake-test-target
    # for now we explicitly run it:
    if(${uprefix}VALGRIND)
        separate_arguments(_vg_opts UNIX_COMMAND "${${uprefix}VALGRIND_OPTIONS}")
        add_test(NAME ${target_name}-valgrind COMMAND valgrind ${_vg_opts} $<TARGET_FILE:${target_name}>)
    endif()
    if(${uprefix}VALGRIND_SGCHECK)
        # stack and global array overrun detector
        # http://valgrind.org/docs/manual/sg-manual.html
        separate_arguments(_sg_opts UNIX_COMMAND "--tool=exp-sgcheck ${${uprefix}VALGRIND_OPTIONS}")
        add_test(NAME ${target_name}-sgcheck COMMAND valgrind ${_sg_opts} $<TARGET_FILE:${target_name}>)
    endif()
endfunction(c4_add_valgrind)


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
function(c4_setup_coverage prefix)
    _c4_handle_prefix(${prefix})
    set(_covok ON)
    if("${CMAKE_CXX_COMPILER_ID}" MATCHES "(Apple)?[Cc]lang")
        if("${CMAKE_CXX_COMPILER_VERSION}" VERSION_LESS 3)
	    message(STATUS "${prefix} coverage: clang version must be 3.0.0 or greater. No coverage available.")
            set(_covok OFF)
        endif()
    elseif(NOT CMAKE_COMPILER_IS_GNUCXX)
        message(STATUS "${prefix} coverage: compiler is not GNUCXX. No coverage available.")
        set(_covok OFF)
    endif()
    if(NOT _covok)
        return()
    endif()
    set(_covon OFF)
    if(CMAKE_BUILD_TYPE STREQUAL "Coverage")
        set(_covon ON)
    endif()
    option(${uprefix}COVERAGE "enable coverage targets" ${_covon})
    cmake_dependent_option(${uprefix}COVERAGE_CODECOV "enable coverage with codecov" ON ${uprefix}COVERAGE OFF)
    cmake_dependent_option(${uprefix}COVERAGE_COVERALLS "enable coverage with coveralls" ON ${uprefix}COVERAGE OFF)
    if(${uprefix}COVERAGE)
        set(covflags "-g -O0 -fprofile-arcs -ftest-coverage --coverage -fno-inline -fno-inline-small-functions -fno-default-inline")
        #set(covflags "-g -O0 -fprofile-arcs -ftest-coverage")
        add_configuration_type(Coverage
            DEFAULT_FROM DEBUG
            C_FLAGS ${covflags}
            CXX_FLAGS ${covflags}
            )
        if(${CMAKE_BUILD_TYPE} STREQUAL "Coverage")
            if(${uprefix}COVERAGE_CODECOV)
                #include(CodeCoverage)
            endif()
            if(${uprefix}COVERAGE_COVERALLS)
                #include(Coveralls)
                #coveralls_turn_on_coverage() # NOT NEEDED, we're doing this manually.
            endif()
            find_program(GCOV gcov)
            find_program(LCOV lcov)
            find_program(GENHTML genhtml)
            find_program(CTEST ctest)
            if(GCOV AND LCOV AND GENHTML AND CTEST)
                add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/lcov/index.html
                    COMMAND ${LCOV} -q --zerocounters --directory .
                    COMMAND ${LCOV} -q --no-external --capture --base-directory "${CMAKE_SOURCE_DIR}" --directory . --output-file before.lcov --initial
                    COMMAND ${CTEST} --force-new-ctest-process
                    COMMAND ${LCOV} -q --no-external --capture --base-directory "${CMAKE_SOURCE_DIR}" --directory . --output-file after.lcov
                    COMMAND ${LCOV} -q --add-tracefile before.lcov --add-tracefile after.lcov --output-file final.lcov
                    COMMAND ${LCOV} -q --remove final.lcov "'${CMAKE_SOURCE_DIR}/test/*'" "'/usr/*'" "'*/extern/*'" --output-file final.lcov
                    COMMAND ${GENHTML} final.lcov -o lcov --demangle-cpp --sort -p "${CMAKE_BINARY_DIR}" -t ${lcprefix}
                    DEPENDS ${lprefix}test
                    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
                    COMMENT "${prefix} coverage: Running LCOV"
                    )
                add_custom_target(${lprefix}coverage
                    DEPENDS ${CMAKE_BINARY_DIR}/lcov/index.html
                    COMMENT "${lcprefix} coverage: LCOV report at ${CMAKE_BINARY_DIR}/lcov/index.html"
                    )
                message(STATUS "Coverage command added")
            else()
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
        endif()
    endif()
endfunction(c4_setup_coverage)


endif() # NOT _c4_project_included
