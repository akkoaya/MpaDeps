function(detect_mpadeps_triplet outvar)
  string(TOLOWER "${CMAKE_SYSTEM_NAME}" mpadeps_triplet_system)
  string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" mpadeps_triplet_arch)

  if(mpadeps_triplet_system STREQUAL "darwin")
    set(mpadeps_triplet_system "osx")
    list(LENGTH CMAKE_OSX_ARCHITECTURES osx_archcount)
    if(osx_archcount GREATER 1)
      message(FATAL_ERROR "More than one CMAKE_OSX_ARCHITECTURES is not supported")
    elseif(osx_archcount EQUAL 0)
      message(STATUS "No CMAKE_OSX_ARCHITECTURES given, default to ${mpadeps_triplet_arch}")
    else()
      set(mpadeps_triplet_arch "${CMAKE_OSX_ARCHITECTURES}")
    endif()
  endif()

  if(mpadeps_triplet_arch MATCHES "(amd64|x86_64)")
    set(mpadeps_triplet_arch "x64")
  elseif(mpadeps_triplet_arch MATCHES "i[3456]86")
    set(mpadeps_triplet_arch "x86")
  elseif(mpadeps_triplet_arch MATCHES "(aarch64|armv8l|arm64)")
    set(mpadeps_triplet_arch "arm64")
  else()
    message(FATAL_ERROR "Unrecognized CMAKE_SYSTEM_PROCESSOR: ${CMAKE_SYSTEM_PROCESSOR}")
  endif()

  set(${outvar} "mpa-${mpadeps_triplet_arch}-${mpadeps_triplet_system}" PARENT_SCOPE)
endfunction()

function(detect_mpadeps_host_triplet outvar)
  string(TOLOWER "${CMAKE_HOST_SYSTEM_NAME}" mpadeps_triplet_system)
  string(TOLOWER "${CMAKE_HOST_SYSTEM_PROCESSOR}" mpadeps_triplet_arch)

  if(mpadeps_triplet_system STREQUAL "darwin")
    set(mpadeps_triplet_system "osx")
  endif()

  if(mpadeps_triplet_arch MATCHES "(amd64|x86_64)")
    set(mpadeps_triplet_arch "x64")
  elseif(mpadeps_triplet_arch MATCHES "i[3456]86")
    set(mpadeps_triplet_arch "x86")
  elseif(mpadeps_triplet_arch MATCHES "(aarch64|armv8l|arm64)")
    set(mpadeps_triplet_arch "arm64")
  else()
    message(FATAL_ERROR "Unrecognized CMAKE_HOST_SYSTEM_PROCESSOR: ${CMAKE_HOST_SYSTEM_PROCESSOR}")
  endif()

  set(${outvar} "${mpadeps_triplet_arch}-${mpadeps_triplet_system}" PARENT_SCOPE)
endfunction()

if(NOT DEFINED MPADEPS_TRIPLET)
  detect_mpadeps_triplet(MPADEPS_TRIPLET)
  set(MPADEPS_TRIPLET "${MPADEPS_TRIPLET}" CACHE STRING "")
  message(STATUS "Use autodetected MPADEPS_TRIPLET: ${MPADEPS_TRIPLET}, override it if not correct.")
endif()

set(_MPADEPS_PREFIX "${CMAKE_CURRENT_LIST_DIR}/vcpkg/installed/${MPADEPS_TRIPLET}")
detect_mpadeps_host_triplet(MPADEPS_HOST_TRIPLET)
set(_MPADEPS_HOST_PREFIX "${CMAKE_CURRENT_LIST_DIR}/vcpkg/installed/${MPADEPS_HOST_TRIPLET}")
if(NOT EXISTS "${_MPADEPS_PREFIX}")
  message(FATAL_ERROR
    " "
    " Dependencies not found for ${MPADEPS_TRIPLET}\n"
    " bootstrap or build MpaDeps first.\n"
    " Expected path: ${_MPADEPS_PREFIX}\n"
  )
endif()

if(CMAKE_CROSSCOMPILING)
  list(PREPEND CMAKE_FIND_ROOT_PATH "${_MPADEPS_PREFIX}")
else()
  list(PREPEND CMAKE_PREFIX_PATH "${_MPADEPS_PREFIX}")
endif()

if(EXISTS "${_MPADEPS_HOST_PREFIX}/tools")
  file(GLOB _MPADEPS_HOST_TOOL_DIRS LIST_DIRECTORIES true "${_MPADEPS_HOST_PREFIX}/tools/*")
  list(PREPEND CMAKE_PROGRAM_PATH "${_MPADEPS_HOST_PREFIX}/tools")
  foreach(_mpadeps_tool_dir IN LISTS _MPADEPS_HOST_TOOL_DIRS)
    if(IS_DIRECTORY "${_mpadeps_tool_dir}")
      list(PREPEND CMAKE_PROGRAM_PATH "${_mpadeps_tool_dir}")
    endif()
  endforeach()
  unset(_mpadeps_tool_dir)
  unset(_MPADEPS_HOST_TOOL_DIRS)

  if(
    NOT DEFINED Protobuf_PROTOC_EXECUTABLE
    OR NOT Protobuf_PROTOC_EXECUTABLE
    OR Protobuf_PROTOC_EXECUTABLE MATCHES "-NOTFOUND$"
    OR NOT EXISTS "${Protobuf_PROTOC_EXECUTABLE}"
  )
    if(WIN32)
      set(_MPADEPS_PROTOC_PATH "${_MPADEPS_HOST_PREFIX}/tools/protobuf/protoc.exe")
    else()
      set(_MPADEPS_PROTOC_PATH "${_MPADEPS_HOST_PREFIX}/tools/protobuf/protoc")
    endif()
    if(EXISTS "${_MPADEPS_PROTOC_PATH}")
      set(Protobuf_PROTOC_EXECUTABLE "${_MPADEPS_PROTOC_PATH}" CACHE FILEPATH "Host protoc shipped with MpaDeps" FORCE)
      set(PROTOBUF_PROTOC_EXECUTABLE "${_MPADEPS_PROTOC_PATH}" CACHE FILEPATH "Host protoc shipped with MpaDeps" FORCE)
    endif()
    unset(_MPADEPS_PROTOC_PATH)
  endif()
endif()

function(mpadeps_install dest)
  if(MSVC)
    install(
      DIRECTORY "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/runtime/${MPADEPS_TRIPLET}/$<$<CONFIG:Debug>:msvc-debug/>"
      DESTINATION ${dest}
      USE_SOURCE_PERMISSIONS
    )
  else()
    install(
      DIRECTORY "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/runtime/${MPADEPS_TRIPLET}/"
      DESTINATION ${dest}
      USE_SOURCE_PERMISSIONS
    )
  endif()
endfunction()

function(mpadeps_deploy_runtime target_name)
  if(NOT TARGET "${target_name}")
    message(FATAL_ERROR "mpadeps_deploy_runtime target does not exist: ${target_name}")
  endif()

  if(MSVC)
    set(_mpadeps_runtime_source
      "$<IF:$<CONFIG:Debug>,${CMAKE_CURRENT_FUNCTION_LIST_DIR}/runtime/${MPADEPS_TRIPLET}/msvc-debug,${CMAKE_CURRENT_FUNCTION_LIST_DIR}/runtime/${MPADEPS_TRIPLET}>")
  else()
    set(_mpadeps_runtime_source
      "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/runtime/${MPADEPS_TRIPLET}")
  endif()

  add_custom_command(
    TARGET "${target_name}" POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_directory
            "${_mpadeps_runtime_source}"
            "$<TARGET_FILE_DIR:${target_name}>"
    VERBATIM
  )
endfunction()
