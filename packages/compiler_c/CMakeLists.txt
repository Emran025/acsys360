cmake_minimum_required(VERSION 3.16)
project(arabicc_c LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

find_package(BISON REQUIRED)
find_package(FLEX REQUIRED)

bison_target(ArabicParser src/parser.y ${CMAKE_CURRENT_BINARY_DIR}/parser.tab.c COMPILE_FLAGS "-d")
flex_target(ArabicLexer src/lexer.l ${CMAKE_CURRENT_BINARY_DIR}/lexer.yy.c)
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
