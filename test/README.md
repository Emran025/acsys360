# Flutter test tree

The Flutter test suite mirrors the Clean Architecture boundaries in `lib/`.

```text
test/
├── core/                         # framework-independent shared services
├── features/editor/
│   ├── domain/
│   │   ├── entities/             # immutable models and state transitions
│   │   ├── services/             # domain coordination services
│   │   └── usecases/             # editor behavior and language rules
│   ├── data/repositories_impl/   # filesystem and process adapters
│   └── presentation/
│       ├── controllers/          # orchestration and async state
│       └── ui/                   # widget and rendering behavior
└── integration/                  # process and external-boundary tests
```

## Rules

- Test files mirror the production layer they exercise.
- Domain tests must not import Flutter widgets; `flutter_test` is used only as
  the test runner where the application package requires it.
- Data tests use temporary resources and fakes; they do not depend on a
  developer machine path.
- Integration tests are the only tests allowed to start `arabicc` or depend on
  a built compiler executable.
- Shared fixtures and test doubles should live under `test/support/` when they
  are reused by more than one test file; keep local doubles beside the test
  when they are specific to one scenario.
