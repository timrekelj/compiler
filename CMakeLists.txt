cmake_minimum_required(VERSION 3.30.0)
project(compiler VERSION 0.1.0 LANGUAGES C)
add_executable(compiler
    main.c
    logging.c
    lexer.c
)
