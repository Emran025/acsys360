# Compiler test tree

```text
tests/
├── unit/         # isolated TAC and assembly golden tests
├── security/     # artifact and path-safety tests
└── integration/  # executable protocol, language, ABI and regression tests
```

CTest is the single entry point for this package. Every executable test is
registered in `CMakeLists.txt`; Dart integration tests are registered only
when a Dart executable is available.
