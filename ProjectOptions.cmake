include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(StereoCam_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(StereoCam_setup_options)
  option(StereoCam_ENABLE_HARDENING "Enable hardening" ON)
  option(StereoCam_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    StereoCam_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    StereoCam_ENABLE_HARDENING
    OFF)

  StereoCam_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR StereoCam_PACKAGING_MAINTAINER_MODE)
    option(StereoCam_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(StereoCam_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(StereoCam_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(StereoCam_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(StereoCam_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(StereoCam_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(StereoCam_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(StereoCam_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(StereoCam_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(StereoCam_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(StereoCam_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(StereoCam_ENABLE_PCH "Enable precompiled headers" OFF)
    option(StereoCam_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(StereoCam_ENABLE_IPO "Enable IPO/LTO" ON)
    option(StereoCam_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(StereoCam_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(StereoCam_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(StereoCam_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(StereoCam_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(StereoCam_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(StereoCam_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(StereoCam_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(StereoCam_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(StereoCam_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(StereoCam_ENABLE_PCH "Enable precompiled headers" OFF)
    option(StereoCam_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      StereoCam_ENABLE_IPO
      StereoCam_WARNINGS_AS_ERRORS
      StereoCam_ENABLE_USER_LINKER
      StereoCam_ENABLE_SANITIZER_ADDRESS
      StereoCam_ENABLE_SANITIZER_LEAK
      StereoCam_ENABLE_SANITIZER_UNDEFINED
      StereoCam_ENABLE_SANITIZER_THREAD
      StereoCam_ENABLE_SANITIZER_MEMORY
      StereoCam_ENABLE_UNITY_BUILD
      StereoCam_ENABLE_CLANG_TIDY
      StereoCam_ENABLE_CPPCHECK
      StereoCam_ENABLE_COVERAGE
      StereoCam_ENABLE_PCH
      StereoCam_ENABLE_CACHE)
  endif()

  StereoCam_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (StereoCam_ENABLE_SANITIZER_ADDRESS OR StereoCam_ENABLE_SANITIZER_THREAD OR StereoCam_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(StereoCam_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(StereoCam_global_options)
  if(StereoCam_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    StereoCam_enable_ipo()
  endif()

  StereoCam_supports_sanitizers()

  if(StereoCam_ENABLE_HARDENING AND StereoCam_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR StereoCam_ENABLE_SANITIZER_UNDEFINED
       OR StereoCam_ENABLE_SANITIZER_ADDRESS
       OR StereoCam_ENABLE_SANITIZER_THREAD
       OR StereoCam_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${StereoCam_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${StereoCam_ENABLE_SANITIZER_UNDEFINED}")
    StereoCam_enable_hardening(StereoCam_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(StereoCam_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(StereoCam_warnings INTERFACE)
  add_library(StereoCam_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  StereoCam_set_project_warnings(
    StereoCam_warnings
    ${StereoCam_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(StereoCam_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(StereoCam_options)
  endif()

  include(cmake/Sanitizers.cmake)
  StereoCam_enable_sanitizers(
    StereoCam_options
    ${StereoCam_ENABLE_SANITIZER_ADDRESS}
    ${StereoCam_ENABLE_SANITIZER_LEAK}
    ${StereoCam_ENABLE_SANITIZER_UNDEFINED}
    ${StereoCam_ENABLE_SANITIZER_THREAD}
    ${StereoCam_ENABLE_SANITIZER_MEMORY})

  set_target_properties(StereoCam_options PROPERTIES UNITY_BUILD ${StereoCam_ENABLE_UNITY_BUILD})

  if(StereoCam_ENABLE_PCH)
    target_precompile_headers(
      StereoCam_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(StereoCam_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    StereoCam_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(StereoCam_ENABLE_CLANG_TIDY)
    StereoCam_enable_clang_tidy(StereoCam_options ${StereoCam_WARNINGS_AS_ERRORS})
  endif()

  if(StereoCam_ENABLE_CPPCHECK)
    StereoCam_enable_cppcheck(${StereoCam_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(StereoCam_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    StereoCam_enable_coverage(StereoCam_options)
  endif()

  if(StereoCam_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(StereoCam_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(StereoCam_ENABLE_HARDENING AND NOT StereoCam_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR StereoCam_ENABLE_SANITIZER_UNDEFINED
       OR StereoCam_ENABLE_SANITIZER_ADDRESS
       OR StereoCam_ENABLE_SANITIZER_THREAD
       OR StereoCam_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    StereoCam_enable_hardening(StereoCam_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
