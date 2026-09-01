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
  src/parser.c
  src/semantic.c
  src/tac.c
  src/typed_ir.c
  src/asm_x86_64.c
)
target_include_directories(arabicc_c PRIVATE include)

enable_testing()
add_executable(arabicc_c_lexer_test tests/lexer_test.c src/lexer.c src/ast.c src/parser.c src/semantic.c)
target_include_directories(arabicc_c_lexer_test PRIVATE include)
add_test(NAME arabicc_c_lexer_test COMMAND arabicc_c_lexer_test)
add_executable(arabicc_c_parser_test tests/parser_test.c src/lexer.c src/ast.c src/parser.c src/semantic.c)
target_include_directories(arabicc_c_parser_test PRIVATE include)
add_test(NAME arabicc_c_parser_test COMMAND arabicc_c_parser_test)
add_executable(arabicc_c_semantic_test tests/semantic_test.c src/lexer.c src/ast.c src/parser.c src/semantic.c src/tac.c)
target_include_directories(arabicc_c_semantic_test PRIVATE include)
add_test(NAME arabicc_c_semantic_test COMMAND arabicc_c_semantic_test)
add_executable(arabicc_c_tac_test tests/tac_test.c src/lexer.c src/ast.c src/parser.c src/semantic.c src/tac.c src/typed_ir.c)
target_include_directories(arabicc_c_tac_test PRIVATE include)
add_test(NAME arabicc_c_tac_test COMMAND arabicc_c_tac_test)
add_executable(arabicc_c_typed_ir_test tests/typed_ir_test.c src/lexer.c src/ast.c src/parser.c src/semantic.c src/tac.c src/typed_ir.c src/asm_x86_64.c)
target_include_directories(arabicc_c_typed_ir_test PRIVATE include)
add_test(NAME arabicc_c_typed_ir_test COMMAND arabicc_c_typed_ir_test)
add_executable(arabicc_c_asm_test tests/asm_test.c src/lexer.c src/ast.c src/parser.c src/semantic.c src/tac.c src/typed_ir.c src/asm_x86_64.c)
target_include_directories(arabicc_c_asm_test PRIVATE include)
add_test(NAME arabicc_c_asm_test COMMAND arabicc_c_asm_test)
