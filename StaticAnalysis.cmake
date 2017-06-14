include(PVS-Studio)
include(GetFlags)
include(GetTargetPropertyRecursive)


function(setup_static_analysis prefix)
    if(prefix)
        set(prefix "${prefix}_")
    endif()
    # option to turn sanitize on/off
    option(${prefix}LINT "turn on static analyzers" OFF)
    # options for individual sanitizers - contingent on sanitize on/off
    cmake_dependent_option(${prefix}LINT_CLANG_TIDY "use the clang-tidy static analyzer" ON "${prefix}LINT" OFF)
    cmake_dependent_option(${prefix}LINT_PVS_STUDIO "use the PVS-Studio static analyzer https://www.viva64.com/en/b/0457/" ON "${prefix}LINT" OFF)
    if(${prefix}LINT_PVS_STUDIO)
        set(${prefix}LINT_PVS_STUDIO_FORMAT "errorfile" CACHE STRING "PVS-Studio output format. Choices: xml,csv,errorfile(like gcc/clang),tasklist(qtcreator)")
    endif()
endfunction()


function(static_analysis_target prefix target_name folder)
    string(TOUPPER ${prefix} uprefix)
    if(uprefix)
        set(uprefix "${uprefix}_")
    endif()
    string(TOLOWER ${prefix} lprefix)
    if(lprefix)
        set(lprefix "${lprefix}-")
    endif()
    if(${uprefix}LINT AND (${uprefix}LINT_CLANG_TIDY OR ${uprefix}LINT_PVS_STUDIO))
        if(NOT TARGET ${lprefix}lint-all)
            add_custom_target(${lprefix}lint-all)
            if(folder)
                message(STATUS "${target_name}: folder=${folder}")
                set_target_properties(${lprefix}lint-all PROPERTIES FOLDER "${folder}")
            endif()
        endif()
        if(${uprefix}LINT_CLANG_TIDY)
            static_analysis_clang_tidy(${target_name}
                ${target_name}-lint-clang-tidy
                ${lprefix}lint-clang-tidy
                "${folder}")
            add_dependencies(${lprefix}lint-all ${lprefix}lint-clang-tidy)
        endif()
        if(${uprefix}LINT_PVS_STUDIO)
            static_analysis_pvs_studio(${target_name}
                ${target_name}-lint-pvs-studio
                ${lprefix}lint-pvs-studio
                "${folder}")
            add_dependencies(${lprefix}lint-all ${lprefix}lint-pvs-studio)
        endif()
    endif()
endfunction()


function(static_analysis_clang_tidy subj_target lint_target umbrella_target folder)
    get_target_property(_clt_srcs ${subj_target} SOURCES)
    get_target_property(_clt_opts ${subj_target} COMPILE_OPTIONS)
    get_target_property_recursive(_clt_incs ${subj_target} INCLUDE_DIRECTORIES)
    get_include_flags(_clt_incs ${_clt_incs})
    if(NOT _clt_opts)
        set(_clt_opts)
    endif()
    separate_arguments(_clt_opts UNIX_COMMAND "${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}} ${_clt_opts}")
    separate_arguments(_clt_incs UNIX_COMMAND "${_clt_incs}")
    add_custom_target(${lint_target}
        COMMAND clang-tidy ${_clt_srcs} --config='' -- ${_clt_incs} ${_clt_opts}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    if(folder)
        set_target_properties(${lint_target} PROPERTIES FOLDER "${folder}")
    endif()
    if(NOT TARGET ${umbrella_target})
        add_custom_target(${umbrella_target})
    endif()
    add_dependencies(${umbrella_target} ${lint_target})
endfunction()


function(static_analysis_pvs_studio subj_target lint_target umbrella_target folder)
    get_target_property_recursive(_c4al_pvs_incs ${subj_target} INCLUDE_DIRECTORIES)
    get_include_flags(_c4al_pvs_incs ${_c4al_pvs_incs})
    separate_arguments(_c4al_cxx_flags_sep UNIX_COMMAND "${CMAKE_CXX_FLAGS} ${_c4al_pvs_incs}")
    separate_arguments(_c4al_c_flags_sep UNIX_COMMAND "${CMAKE_C_FLAGS} ${_c4al_pvs_incs}")
    pvs_studio_add_target(TARGET ${lint_target}
        ALL # indicates that the analysis starts when you build the project
        #PREPROCESSOR ${_c4al_preproc}
        FORMAT tasklist
        LOG "${CMAKE_CURRENT_BINARY_DIR}/${subj_target}.pvs-analysis.tasks"
        ANALYZE ${name} #main_target subtarget:path/to/subtarget
        CXX_FLAGS ${_c4al_cxx_flags_sep}
        C_FLAGS ${_c4al_c_flags_sep}
        #CONFIG "/path/to/PVS-Studio.cfg"
        )
    if(folder)
        set_target_properties(${lint_target} PROPERTIES FOLDER "${folder}")
    endif()
    if(NOT TARGET ${umbrella_target})
        add_custom_target(${umbrella_target})
    endif()
    add_dependencies(${umbrella_target} ${lint_target})
endfunction()
