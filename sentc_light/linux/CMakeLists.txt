# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "sentc_light")
project(${PROJECT_NAME} LANGUAGES CXX)

set(sentc_bundled_libraries
        "${CMAKE_CURRENT_SOURCE_DIR}/${FLUTTER_TARGET_PLATFORM}/libsentc_light_flutter.so"
        PARENT_SCOPE
)
