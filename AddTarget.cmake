include(ConfigurationTypes)
include(CreateSourceGroup)
include(SanitizeTarget)
include(StaticAnalysis)

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# example: add_target(RYML ryml LIBRARY SOURCES ${SRC})
function(add_target prefix name)
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
    set(options0arg
        LIBRARY
        EXECUTABLE
        SANITIZE
    )
    set(options1arg
        OUTPUT_TARGET_NAMES
        FOLDER
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
        static_analysis_target(${ucprefix} ${name} "${_c4al_FOLDER}")
    endif()
    if(_c4al_SANITIZE AND ${uprefix}SANITIZE)
        sanitize_target(${name} ${lcprefix}
            ${_what}
            SOURCES ${_c4al_SOURCES}
            INC_DIRS ${_c4al_INC_DIRS}
            LIBS ${_c4al_LIBS}
            OUTPUT_TARGET_NAMES targets
            FOLDER "${_c4al_FOLDER}"
            )
    endif()
    if(NOT ${uprefix}SANITIZE_ONLY)
        list(INSERT targets 0 ${name})
    endif()
    if(_c4al_OUTPUT_TARGET_NAMES)
        set(${_c4al_OUTPUT_TARGET_NAMES} ${targets} PARENT_SCOPE)
    endif()
endfunction() # add_target
