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

add_executable(arabicc_c
  src/main.c
  src/protocol.c
  src/ast.c
  ${BISON_ArabicParser_OUTPUTS}
  ${FLEX_ArabicLexer_OUTPUTS}
)

target_include_directories(arabicc_c PRIVATE
  include
  src
  ${CMAKE_CURRENT_BINARY_DIR}
)

enable_testing()
add_test(NAME arabicc_version COMMAND arabicc_c --version)
add_test(NAME arabicc_help COMMAND arabicc_c --help)
