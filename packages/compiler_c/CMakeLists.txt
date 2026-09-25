cmake_minimum_required(VERSION 3.16)
project(arabicc_c LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

find_package(BISON REQUIRED)
find_package(FLEX REQUIRED)

set(ARABICC_GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
file(MAKE_DIRECTORY ${ARABICC_GENERATED_DIR})

bison_target(ArabicParser src/parser.y ${ARABICC_GENERATED_DIR}/parser.tab.c
  COMPILE_FLAGS "-d -Wno-other -Wno-conflicts-sr -Wno-conflicts-rr")
set(ARABICC_FLEX_FLAGS "")
if(WIN32)
  # win_flex otherwise emits an unconditional <unistd.h> include, which is
  # not available when the generated scanner is compiled with MSVC.
  set(ARABICC_FLEX_FLAGS "--wincompat")
endif()
flex_target(ArabicLexer src/lexer.l ${ARABICC_GENERATED_DIR}/lexer.yy.c
  COMPILE_FLAGS "${ARABICC_FLEX_FLAGS}")
add_flex_bison_dependency(ArabicLexer ArabicParser)

add_executable(arabicc
  src/main.c
  src/protocol.c
  src/protocol/protocol_json.c
  src/protocol/protocol_request.c
  src/protocol/protocol_response.c
  src/driver/compiler_driver.c
  src/ir/typed_ir.c
  src/runtime/interpreter.c
  src/backend/artifact_builder.c
  src/backend/toolchain.c
  src/ast.c
  src/semantic.c
  src/ir/tac.c
  src/asm_x86_64.c
  ${BISON_ArabicParser_OUTPUTS}
  ${FLEX_ArabicLexer_OUTPUTS}
)

set_target_properties(arabicc PROPERTIES OUTPUT_NAME "arabicc")

if(UNIX)
  target_link_libraries(arabicc PRIVATE m)
endif()

target_include_directories(arabicc PRIVATE
  include
  src
  ${ARABICC_GENERATED_DIR}
)

enable_testing()
add_test(NAME arabicc_version COMMAND arabicc --version)
add_test(NAME arabicc_help COMMAND arabicc --help)
add_executable(arabicc_tac_golden_test
  tests/tac_golden_test.c
  src/ir/tac.c
  src/ast.c
)
target_include_directories(arabicc_tac_golden_test PRIVATE include)
add_test(NAME arabicc_tac_golden COMMAND arabicc_tac_golden_test)
add_executable(arabicc_artifact_security_test
  tests/artifact_security_test.c
  src/backend/artifact_builder.c
  src/backend/toolchain.c
)
target_include_directories(arabicc_artifact_security_test PRIVATE include)
add_test(NAME arabicc_artifact_security COMMAND arabicc_artifact_security_test)
find_program(DART_EXECUTABLE dart)
if(DART_EXECUTABLE)
  add_test(NAME arabicc_protocol_smoke
    COMMAND ${DART_EXECUTABLE}
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/protocol_smoke.dart
            $<TARGET_FILE:arabicc>)
  add_test(NAME arabicc_manual_examples
    COMMAND ${DART_EXECUTABLE}
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/manual_examples.dart
            $<TARGET_FILE:arabicc>)
  add_test(NAME arabicc_semicolon_rule
    COMMAND ${DART_EXECUTABLE}
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/semicolon_rule.dart
            $<TARGET_FILE:arabicc>)
  add_test(NAME arabicc_composite_types
    COMMAND ${DART_EXECUTABLE}
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/composite_types.dart
            $<TARGET_FILE:arabicc>)
  add_test(NAME arabicc_stability
    COMMAND ${DART_EXECUTABLE}
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/stability.dart
            $<TARGET_FILE:arabicc>)
else()
  message(STATUS "Dart not found: skipping compiler Dart integration tests")
endif()
