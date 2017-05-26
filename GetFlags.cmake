
function(get_define outvar defname)
    if(MSVC AND "${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC") # it may be clang as well
        set(flagchar "/")
    else()
        set(flagchar "-")
    endif()
    set(defvalue ${ARGN})
    if(defvalue)
        set(${outvar} "${flagchar}D ${defname}=${defvalue}" PARENT_SCOPE)
    else()
        set(${outvar} "${flagchar}D ${defname}" PARENT_SCOPE)
    endif()
endfunction()
