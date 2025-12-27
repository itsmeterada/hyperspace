cmake_minimum_required(VERSION 3.10)
project(hyperspace C)

set(CMAKE_C_STANDARD 99)

# Find SDL2
find_package(SDL2 REQUIRED)

# Add executable
add_executable(hyperspace hyperspace_sdl2.c)

# Link SDL2
target_include_directories(hyperspace PRIVATE ${SDL2_INCLUDE_DIRS})
target_link_libraries(hyperspace ${SDL2_LIBRARIES} m)

# Windows specific
if(WIN32)
    target_link_libraries(hyperspace mingw32 SDL2main SDL2)
endif()

# Copy p8 file to build directory
configure_file(${CMAKE_SOURCE_DIR}/hyperspace.lua.p8 ${CMAKE_BINARY_DIR}/hyperspace.lua.p8 COPYONLY)
