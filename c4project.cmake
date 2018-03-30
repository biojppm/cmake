if(NOT _c4_project_included)
set(_c4_project_included ON)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

include(ConfigurationTypes)
include(CreateSourceGroup)
include(SanitizeTarget)
include(StaticAnalysis)
include(PrintVar)

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

function(c4_add_library prefix name)
    c4_add_target(${prefix} ${name} LIBRARY ${ARGN})
endfunction(c4_add_library)

function(c4_add_executable prefix name)
    c4_add_target(${prefix} ${name} EXECUTABLE ${ARGN})
endfunction(c4_add_executable)

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# example: c4_add_target(RYML ryml LIBRARY SOURCES ${SRC})
function(c4_add_target prefix name)
    #message(STATUS "${prefix}: adding target: ${name}: ${ARGN}")
    _c4_handle_prefix(${prefix})
    set(options0arg
        LIBRARY
        EXECUTABLE
        SANITIZE
    )
    set(options1arg
        FOLDER
        SANITIZERS  # outputs the list of sanitize targets in this var
    )
    set(optionsnarg
        SOURCES
        INC_DIRS
        LIBS
        MORE_ARGS
    )
    cmake_parse_arguments(_c4al "${options0arg}" "${options1arg}" "${optionsnarg}" ${ARGN})
    if(${_c4al_LIBRARY})
        set(_what LIBRARY)
    elseif(${_c4al_EXECUTABLE})
        set(_what EXECUTABLE)
    endif()

    create_source_group("" "${CMAKE_CURRENT_SOURCE_DIR}" "${_c4al_SOURCES}")

    if(NOT ${uprefix}SANITIZE_ONLY)
        if(${_c4al_LIBRARY})
            add_library(${name} ${_c4al_SOURCES} ${_c4al_MORE_ARGS})
        elseif(${_c4al_EXECUTABLE})
            add_executable(${name} ${_c4al_SOURCES} ${_c4al_MORE_ARGS})
        endif()
        if(_c4al_INC_DIRS)
            target_include_directories(${name} PUBLIC ${_c4al_INC_DIRS})
        endif()
        if(_c4al_LIBS)
            target_link_libraries(${name} PUBLIC ${_c4al_LIBS})
        endif()
        if(_c4al_FOLDER)
            set_target_properties(${name} PROPERTIES FOLDER "${_c4al_FOLDER}")
        endif()
        if(${uprefix}CXX_FLAGS)
            #print_var(${uprefix}CXX_FLAGS)
            set_target_properties(${name} PROPERTIES COMPILE_FLAGS ${${uprefix}CXX_FLAGS})
        endif()
        if(${uprefix}LINT)
            static_analysis_target(${ucprefix} ${name} "${_c4al_FOLDER}" lint_targets)
        endif()
    endif()

    if(_c4al_SANITIZE OR ${uprefix}SANITIZE)
        sanitize_target(${name} ${lcprefix}
            ${_what}
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

endfunction() # add_target

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
                message(STATUS "adding test: ${t}-run")
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
