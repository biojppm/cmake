function(status)
    message(STATUS "${ARGV}")
endfunction()

function(print_var var)
    message(STATUS "${var}=${${var}} ${ARGN}")
endfunction()

function(print_vars)
    foreach(a ${ARGN})
        message(STATUS "${a}=${${a}}")
    endforeach(a)
endfunction()

function(debug_var debug var)
    if(${debug})
        message(STATUS "${var}=${${var}} ${ARGN}")
    endif()
endfunction()

function(debug_vars debug)
    if(${debug})
        foreach(a ${ARGN})
            message(STATUS "${a}=${${a}}")
        endforeach(a)
    endif()
endfunction()
