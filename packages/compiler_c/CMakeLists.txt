cmake_minimum_required(VERSION 3.16)
project(arabicc_c LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

add_compile_options(-Wall -Wextra -Werror -pedantic)

add_executable(arabicc_c
  src/main.c
  src/protocol.c
  src/lexer.c
  src/ast.c
)
target_include_directories(arabicc_c PRIVATE include)

enable_testing()
add_executable(arabicc_c_lexer_test tests/lexer_test.c src/lexer.c src/ast.c)
target_include_directories(arabicc_c_lexer_test PRIVATE include)
add_test(NAME arabicc_c_lexer_test COMMAND arabicc_c_lexer_test)
