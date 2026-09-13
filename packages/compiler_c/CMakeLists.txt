cmake_minimum_required(VERSION 3.16)
project(arabicc_c LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

find_package(BISON REQUIRED)
find_package(FLEX REQUIRED)

bison_target(ArabicParser src/parser.y ${CMAKE_CURRENT_BINARY_DIR}/parser.tab.c COMPILE_FLAGS "-d")
set(ARABICC_FLEX_FLAGS "")
if(WIN32)
  # win_flex otherwise emits an unconditional <unistd.h> include, which is
  # not available when the generated scanner is compiled with MSVC.
  set(ARABICC_FLEX_FLAGS "--wincompat")
endif()
flex_target(ArabicLexer src/lexer.l ${CMAKE_CURRENT_BINARY_DIR}/lexer.yy.c
  COMPILE_FLAGS "${ARABICC_FLEX_FLAGS}")
add_flex_bison_dependency(ArabicLexer ArabicParser)

add_executable(arabicc
  src/main.c
  src/protocol.c
  src/ast.c
  src/semantic.c
  src/asm_x86_64.c
  ${BISON_ArabicParser_OUTPUTS}
  ${FLEX_ArabicLexer_OUTPUTS}
)

set_target_properties(arabicc PROPERTIES OUTPUT_NAME "arabicc")

target_include_directories(arabicc PRIVATE
  include
  src
  ${CMAKE_CURRENT_BINARY_DIR}
)

enable_testing()
add_test(NAME arabicc_version COMMAND arabicc --version)
add_test(NAME arabicc_help COMMAND arabicc --help)
find_package(Python3 COMPONENTS Interpreter REQUIRED)
add_test(NAME arabicc_protocol_smoke
  COMMAND Python3::Interpreter
          ${CMAKE_CURRENT_SOURCE_DIR}/tests/protocol_smoke.py
          $<TARGET_FILE:arabicc>)
add_test(NAME arabicc_manual_examples
  COMMAND Python3::Interpreter
          ${CMAKE_CURRENT_SOURCE_DIR}/tests/manual_examples.py
          $<TARGET_FILE:arabicc>)
