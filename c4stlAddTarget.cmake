include(AddTarget)

function(c4stl_add_target name)
    add_target(c4stl ${name} ${ARGN})
endfunction() # c4stl_add_target
