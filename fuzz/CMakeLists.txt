cmake_minimum_required(VERSION 3.1.0 FATAL_ERROR)

# Fuzzer
add_executable(
    "${PROJECT_NAME}-fuzzer"
    "${CMAKE_CURRENT_LIST_DIR}/fuzz.c"
)

# Ensure the fuzzer is being compiled with clang
if (NOT CMAKE_C_COMPILER_ID STREQUAL "Clang")
    message(FATAL_ERROR "Clang is required for libFuzzer!")
endif()

target_compile_options(
    "${PROJECT_NAME}-fuzzer"
    PUBLIC
    -fsanitize=fuzzer
)

target_link_options(
    "${PROJECT_NAME}-fuzzer"
    PUBLIC
    -fsanitize=fuzzer
)

target_link_libraries("${PROJECT_NAME}-fuzzer" PRIVATE SDL2_ttf::${sdl2_ttf_export_name})

if (TARGET SDL2::SDL2main)
    target_link_libraries("${PROJECT_NAME}-fuzzer" PRIVATE SDL2::SDL2main)
endif()
if (BUILD_SHARED_LIBS)
    target_link_libraries("${PROJECT_NAME}-fuzzer" PRIVATE SDL2::SDL2)
else()
    target_link_libraries("${PROJECT_NAME}-fuzzer" PRIVATE SDL2::SDL2-static)
endif()
