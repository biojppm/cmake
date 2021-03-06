function(get_lib_names lib_names base)
    set(${lib_names})
    foreach(__glnname ${ARGN})
        if(WIN32)
            set(__glnn ${__glnname}.lib)
        else()
            set(__glnn lib${__glnname}.a)
        endif()
        list(APPEND ${lib_names} "${base}${__glnn}")
    endforeach()
    set(lib_names ${lib_names} PARENT_SCOPE)
endfunction()

function(get_dll_names dll_names base)
    set(${dll_names})
    foreach(__glnname ${ARGN})
        if(WIN32)
            set(__glnn ${__glnname}.dll)
        else()
            set(__glnn lib${__glnname}.so)
        endif()
        list(APPEND ${dll_names} "${base}${__glnn}")
    endforeach()
    set(dll_names ${dll_names} PARENT_SCOPE)
endfunction()

function(get_script_names script_names base)
    set(${script_names})
    foreach(__glnname ${ARGN})
        if(WIN32)
            set(__glnn ${__glnname}.bat)
        else()
            set(__glnn ${__glnname}.sh)
        endif()
        list(APPEND ${script_names} "${base}${__glnn}")
    endforeach()
    set(script_names ${script_names} PARENT_SCOPE)
endfunction()

function(get_exe_names exe_names base)
    set(${exe_names})
    foreach(__glnname ${ARGN})
        if(WIN32)
            set(__glnn ${__glnname}.exe)
        else()
            set(__glnn ${__glnname})
        endif()
        list(APPEND ${exe_names} "${base}${__glnn}")
    endforeach()
    set(exe_names ${exe_names} PARENT_SCOPE)
endfunction()
