
include(ConfigurationTypes)
include(CreateSourceGroup)
include(SanitizeTarget)
include(StaticAnalysis)
include(PrintVar)

set_property(GLOBAL PROPERTY USE_FOLDERS ON)


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# example: c4_add_target(RYML ryml LIBRARY SOURCES ${SRC})
function(c4_add_target prefix name)
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
    endif()
    if(${uprefix}LINT)
        static_analysis_target(${ucprefix} ${name} "${_c4al_FOLDER}" lint_targets)
    endif()
    if(_c4al_SANITIZE AND ${uprefix}SANITIZE)
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
function(c4_setup_testing prefix initial_value)
    if(initial_value)
        _c4_handle_prefix(${prefix})
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
    endif()
endfunction(c4_setup_testing)


function(c4_add_test prefix target sanitized_targets)
    _c4_handle_prefix(${prefix})
    if(NOT ${uprefix}SANITIZE_ONLY)
        add_test(NAME ${target}-run COMMAND $<TARGET_FILE:${target}>)
    endif()
    if(sanitized_targets)
        add_custom_target(${target}-all)
        add_dependencies(${target}-all ${target})
        add_dependencies(${lprefix}test-build ${target}-all)
        set_target_properties(${target}-all PROPERTIES FOLDER ${lprefix}test/${target})
        foreach(s asan msan tsan ubsan)
            set(t ${target}-${s})
            if(TARGET ${t})
                add_dependencies(${target}-all ${t})
                sanitize_get_target_command($<TARGET_FILE:${t}> ${ucprefix} ${s} cmd)
                message(STATUS "adding test: ${t}-run")
                add_test(NAME ${t}-run COMMAND ${cmd})
            endif()
        endforeach()
    else()
        add_dependencies(${lprefix}test-build ${target})
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
function(c4_setup_valgrind prefix initial_value)
    _c4_handle_prefix(${prefix})
    if(UNIX AND NOT COVERAGE_BUILD)
        option(${uprefix}VALGRIND "enable valgrind tests" ${initial_value})
        option(${uprefix}VALGRIND_SGCHECK "enable valgrind tests with the exp-sgcheck tool" ${initial_value})
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
function(c4_setup_coverage prefix initial_value)
    _c4_handle_prefix(${prefix})
    set(${uprefix}COVERAGE_AVAILABLE ${initial_value})
    if("${CMAKE_CXX_COMPILER_ID}" MATCHES "(Apple)?[Cc]lang")
        if("${CMAKE_CXX_COMPILER_VERSION}" VERSION_LESS 3)
	    message(STATUS "Coverage: clang version must be 3.0.0 or greater. No coverage available.")
            set(${uprefix}COVERAGE_AVAILABLE OFF)
        endif()
    elseif(NOT CMAKE_COMPILER_IS_GNUCXX)
        message(STATUS "Coverage: compiler is not GNUCXX. No coverage available.")
        set(${uprefix}COVERAGE_AVAILABLE OFF)
    endif()
    if(${uprefix}COVERAGE_AVAILABLE)
        set(covflags "-g -O0 --coverage -fprofile-arcs -ftest-coverage")
        add_configuration_type(Coverage
            DEFAULT_FROM DEBUG
            C_FLAGS ${covflags}
            CXX_FLAGS ${covflags}
            )
        if(CMAKE_BUILD_TYPE)
            string(TOLOWER ${CMAKE_BUILD_TYPE} CMAKE_BUILD_TYPE_LOWER)
        endif()
        if(${CMAKE_BUILD_TYPE_LOWER} MATCHES "coverage")
            set(COVERAGE_BUILD ON)
            find_program(GCOV gcov)
            find_program(LCOV lcov)
            find_program(GENHTML genhtml)
            find_program(CTEST ctest)
            if (GCOV AND LCOV AND GENHTML AND CTEST)
                add_custom_command(
                    OUTPUT ${CMAKE_BINARY_DIR}/lcov/index.html
                    COMMAND ${LCOV} -q -z -d .
                    COMMAND ${LCOV} -q --no-external -c -b "${CMAKE_SOURCE_DIR}" -d . -o before.lcov -i
                    COMMAND ${CTEST} --force-new-ctest-process
                    COMMAND ${LCOV} -q --no-external -c -b "${CMAKE_SOURCE_DIR}" -d . -o after.lcov
                    COMMAND ${LCOV} -q -a before.lcov -a after.lcov --output-file final.lcov
                    COMMAND ${LCOV} -q -r final.lcov "'${CMAKE_SOURCE_DIR}/test/*'" -o final.lcov
                    COMMAND ${GENHTML} final.lcov -o lcov --demangle-cpp --sort -p "${CMAKE_BINARY_DIR}" -t benchmark
                    DEPENDS ${lprefix}test
                    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
                    COMMENT "Running LCOV"
                    )
                add_custom_target(${lprefix}coverage
                    DEPENDS ${CMAKE_BINARY_DIR}/lcov/index.html
                    COMMENT "LCOV report at ${CMAKE_BINARY_DIR}/lcov/index.html"
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
