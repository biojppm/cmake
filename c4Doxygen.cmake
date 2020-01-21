# (C) 2019 Joao Paulo Magalhaes <dev@jpmag.me>
if(NOT _c4_doxygen_included)
set(_c4_doxygen_included ON)

#------------------------------------------------------------------------------
# TODO use customizations from https://cmake.org/cmake/help/v3.9/module/FindDoxygen.html
function(c4_setup_doxygen umbrella_option)
    cmake_dependent_option(${_c4_uprefix}BUILD_DOCS "Enable targets to build documentation for ${prefix}" ON "${umbrella_option}" OFF)
    if(${_c4_uprefix}BUILD_DOCS)
        find_package(Doxygen QUIET)
        if(DOXYGEN_FOUND)
            c4_dbg("enabling documentation targets")
        else()
            c4_dbg("doxygen not found")
        endif()
    endif()
endfunction()

function(_c4_doxy_list_to_str var)
    set(il)
    foreach(i ${${var}})
        set(il "${il} ${i}")
    endforeach()
    set(${var} "${il}" PARENT_SCOPE)
endfunction()


#------------------------------------------------------------------------------
function(c4_add_doxygen doc_name)
    if(NOT ${_c4_uprefix}BUILD_DOCS)
        return()
    endif()
    if(NOT DOXYGEN_FOUND)
        c4_dbg("doxygen not found, skipping generation of ${doc}")
        return()
    endif()
    #
    set(opt0
        NO_CONFIGURE
    )
    set(opt1
        PROJ
        DOXYFILE
        OUTPUT_DIR
    )
    set(optN
        INPUT
        FILE_PATTERNS
        EXCLUDE
        EXCLUDE_PATTERNS
        STRIP_FROM_PATH
    )
    cmake_parse_arguments("" "${opt0}" "${opt1}" "${optN}" ${ARGN})
    if(NOT _PROJ)
        set(_PROJ ${_c4_ucprefix})
    endif()
    if(NOT _DOXYFILE)
        set(_DOXYFILE ${CMAKE_CURRENT_LIST_DIR}/Doxyfile.in)
    endif()
    if(NOT _OUTPUT_DIR)
        if("${doc_name}" MATCHES "^[Dd]oc")
            set(_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/${doc_name})
        else()
            set(_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/doc/${doc_name})
        endif()
    endif()
    _c4_doxy_list_to_str(_INPUT)
    _c4_doxy_list_to_str(_STRIP_FROM_PATH)
    #
    if("${doc_name}" MATCHES "^[Dd]oc")
        set(tgt ${_c4_lcprefix}-${doc_name})
    else()
        set(tgt ${_c4_lcprefix}-doc-${doc_name})
    endif()
    #
    if(_NO_CONFIGURE)
        set(doxyfile_out ${_DOXYFILE})
    else()
        set(doxyfile_out ${_OUTPUT_DIR}/Doxyfile)
        configure_file(${_DOXYFILE} ${doxyfile_out} @ONLY)
    endif()
    #
    add_custom_target(${tgt}
        COMMAND ${DOXYGEN_EXECUTABLE} ${doxyfile_out}
        WORKING_DIRECTORY ${_OUTPUT_DIR}
        COMMENT "${tgt}: docs will be placed in ${_OUTPUT_DIR}"
        VERBATIM)
    _c4_set_target_folder(${tgt} doc)
endfunction()


endif(NOT _c4_doxygen_included)
