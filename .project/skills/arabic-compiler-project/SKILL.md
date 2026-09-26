---
name: arabic-compiler-project
description: Build the Arabic compiler and VS Code-like Flutter Desktop editor in this repository. Use for grammar, lexer, parser, AST, semantic analysis, runtime, TAC, assembly, multi-file workspaces, editor commands, Clean Architecture, tests, GitHub issues, and CI.
---

# Arabic Compiler Project

## Objective

Build a real Arabic-language compiler integrated with a separate Flutter Desktop editor. Preserve the instructor grammar exactly, expose every compiler stage, and keep the editor productive for multi-file projects with VS Code-like navigation, editing, commands, undo/redo, themes, diagnostics, execution, and project organization.

## Authoritative references

Before modifying language behavior, read `references/language-rules.txt`. Before modifying scope, deliverables, tests, or release behavior, read `references/assignment-requirements.txt`. These are the supplied instructor files and are the project source of truth.

## Non-negotiable deliverables

The compiler must produce real tokens, parse/syntax tree, symbol table, syntax diagnostics, semantic diagnostics, three-address code, assembly code, and an executable artifact when the selected target supports it. The editor and compiler remain separate executables connected through a versioned JSON protocol. The editor must create, open, edit, save, compile, run, show errors and output, and show compiler stages in organized views. Provide at least ten materially different test programs.

## Architecture rules

Use Clean Architecture. Keep domain entities and use cases independent from Flutter and filesystem details. Keep compiler phases pure and typed. Keep process/filesystem adapters at infrastructure boundaries. Do not duplicate compiler logic in the editor. Use one source of truth for documents, diagnostics, project files, and compilation results. Store source spans with line, column, offset, and length.

The current implementation is a Flutter application under `lib/` with the editor feature in `lib/features/editor/`, a standalone C compiler in `packages/compiler_c/`, and Dart protocol models in `packages/compiler_contracts/`. Consult the [current code map](../../../docs/architecture/project-code-map.md) before changing structure. The tree below is an aspirational target layout, not a description of directories that currently exist; do not create or refer to those paths as implemented without an explicit migration task.

### Aspirational repository tree

```text
apps/
  compiler_cli/
  editor_desktop/
packages/
  compiler_core/
    lib/src/{diagnostics,lexer,parser,ast,semantic,runtime,ir,target}
    test/{lexer,parser,semantic,ir}
  compiler_contracts/
  editor_domain/
  editor_data/
  editor_ui/
examples/
docs/{architecture,grammar,roadmap,testing,report}
tool/
.project/skills/arabic-compiler-project/
.github/{ISSUE_TEMPLATE,workflows}
```

## Language scope

Support the complete supplied grammar: program structure; constant, type, variable, and procedure definitions; primitive and compound types; by-value and by-reference parameters; assignment; input/output; calls; if/else forms; `كرر`, `طالما`, and `اعد ... حتى`; expressions with the specified precedence; array indexing; record-field access; Arabic identifiers; literals; punctuation and operators. Do not silently substitute C-like keywords or syntax.

## Editor baseline

The desired editor experience includes a workspace file explorer, multiple tabs, active/dirty document state, open/save/new commands, keyboard shortcuts, find/replace, indentation, formatting, syntax highlighting, light/dark themes, diagnostics and output panels, compiler-stage tabs, run/stop, and predictable per-document undo/redo. A general command palette is a future/optional goal, not a claim about the current UI. Check [product boundaries](../../../docs/architecture/product-boundary.md) and the [code map](../../../docs/architecture/project-code-map.md) to distinguish implemented behavior from planned work. Use command objects or edit transactions for undo/redo. Make all commands testable without a widget pump where possible.

## Tool policy

Prefer Dart and Flutter primitives first. Add parser generators, PEG libraries, syntax-highlighting packages, or editor packages only after recording their version, license, platform support, and role in `docs/architecture/dependencies.md`. A tool may accelerate work but must not hide understanding of the compiler stages required for evaluation.

## Delivery workflow

Work on feature branches and merge through pull requests. Every issue must include goal, dependencies, acceptance criteria, test plan, and explicit out-of-scope items. Every stage must add positive, negative, regression, and golden tests as appropriate. CI must format, analyze, test, build the compiler, run compiler-editor protocol smoke tests, and build the desktop artifact. Never claim a target is supported without running its build.

## RAG usage

For a grammar question, retrieve the smallest relevant section from `language-rules.txt`, then map it to tokens, AST nodes, parser tests, semantic rules, and editor diagnostics. For a deliverable question, retrieve the relevant section from `assignment-requirements.txt`, then update the roadmap and acceptance criteria. Keep generated summaries in `docs/grammar` and avoid duplicating the full references in other files.
