set(VCPKG_LIBRARY_LINKAGE static)
# set(VCPKG_CMAKE_CONFIGURE_OPTIONS ${VCPKG_CMAKE_CONFIGURE_OPTIONS} -DCMAKE_SHARED_LIBRARY_SUFFIX_CXX=_mpa.so)

if(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "Linux")
  # Linux CI uses a hermetic sysroot/toolchain, so X11 development files are
  # not expected to come from the runner. Force vcpkg to build X libraries
  # instead of emitting empty placeholder packages.
  set(X_VCPKG_FORCE_VCPKG_X_LIBRARIES ON)
endif()

if(PORT STREQUAL "opencv4")
  set(VCPKG_LIBRARY_LINKAGE dynamic)
  set(VCPKG_CMAKE_CONFIGURE_OPTIONS ${VCPKG_CMAKE_CONFIGURE_OPTIONS} -DWITH_V4L=OFF)
endif()

if(PORT MATCHES "onnxruntime|mpa-")
  message("setting dynamic linkage for ${PORT}")
  set(VCPKG_LIBRARY_LINKAGE dynamic)
endif()

if (PORT STREQUAL "opencv")
    list(APPEND VCPKG_CMAKE_CONFIGURE_OPTIONS -DBUILD_opencv_hdf=OFF -DBUILD_opencv_quality=OFF)
endif ()

if (PORT STREQUAL "wayland")
  set(X_VCPKG_FORCE_VCPKG_WAYLAND_LIBRARIES ON)
endif ()
