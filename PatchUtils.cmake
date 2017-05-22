# create a script that applies a patch (it's different in windows)

# to generate a patch:
# subversion: svn diff --patch-compatible > path/to/the/patch.diff

function(create_patch_cmd filename_output)
    if(WIN32)
        set(filename ${CMAKE_BINARY_DIR}/apply_patch.bat)
        file(WRITE ${filename} "
set srcdir=%1
set patch=%2
set mark=%3
set prev=%cd%
if not exist %mark% (
    cd %srcdir%
    patch -p0 < %patch%
    cd %prev%
    echo done > %mark%
)
")
    else()
        set(filename ${CMAKE_BINARY_DIR}/apply_patch.sh)
        file(WRITE ${filename} "#!/bin/sh -x
set -e
srcdir=$1
patch=$2
mark=$3
if [ ! -f $mark ] ; then
    cd $srcdir
    patch -p0 < $patch
    cd -
    echo done > $mark
fi
")
    endif()
    set(${filename_output} ${filename} PARENT_SCOPE)
endfunction()
