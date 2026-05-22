cmake_minimum_required(VERSION 3.20)

project(MpaDepsZeroMqSmoke LANGUAGES CXX)

if(NOT DEFINED MPADEPS_PREFIX OR MPADEPS_PREFIX STREQUAL "")
    message(FATAL_ERROR "Set MPADEPS_PREFIX to vcpkg/installed/<triplet>")
endif()

get_filename_component(MPADEPS_PREFIX "${MPADEPS_PREFIX}" ABSOLUTE)
if(NOT EXISTS "${MPADEPS_PREFIX}")
    message(FATAL_ERROR "MPADEPS_PREFIX does not exist: ${MPADEPS_PREFIX}")
endif()

list(PREPEND CMAKE_PREFIX_PATH "${MPADEPS_PREFIX}")

find_package(ZeroMQ CONFIG REQUIRED)
find_package(cppzmq CONFIG REQUIRED)

add_executable(mpadeps_zeromq_smoke main.cpp)
target_compile_features(mpadeps_zeromq_smoke PRIVATE cxx_std_17)

if(TARGET libzmq AND TARGET cppzmq)
    target_link_libraries(mpadeps_zeromq_smoke PRIVATE cppzmq)
elseif(TARGET libzmq-static AND TARGET cppzmq-static)
    target_link_libraries(mpadeps_zeromq_smoke PRIVATE cppzmq-static)
elseif(TARGET cppzmq-static AND TARGET libzmq-static)
    target_link_libraries(mpadeps_zeromq_smoke PRIVATE cppzmq-static)
else()
    message(FATAL_ERROR "ZeroMQ/cppzmq package set did not expose a usable target pair")
endif()
