import 'package:flutter/material.dart';

// ─── Keyboard Intent classes ────────────────────────────────────────────────

class SaveIntent extends Intent {
  const SaveIntent();
}

class SaveAsIntent extends Intent {
  const SaveAsIntent();
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class CompileIntent extends Intent {
  const CompileIntent();
}

class BuildArtifactIntent extends Intent {
  const BuildArtifactIntent();
}

class FindIntent extends Intent {
  const FindIntent();
}

class NewFileIntent extends Intent {
  const NewFileIntent();
}

class OpenFileIntent extends Intent {
  const OpenFileIntent();
}

class CloseEditorIntent extends Intent {
  const CloseEditorIntent();
}

class DeleteLineIntent extends Intent {
  const DeleteLineIntent();
}

class InsertLineIntent extends Intent {
  final bool above;
  const InsertLineIntent({required this.above});
}

class MoveLineIntent extends Intent {
  final int direction;
  const MoveLineIntent({required this.direction});
}

class CopyLineIntent extends Intent {
  final int direction;
  const CopyLineIntent({required this.direction});
}

class SelectLineIntent extends Intent {
  const SelectLineIntent();
}

class NextTabIntent extends Intent {
  const NextTabIntent();
}

class PreviousTabIntent extends Intent {
  const PreviousTabIntent();
}

class NextDiagnosticIntent extends Intent {
  final int direction;
  const NextDiagnosticIntent({required this.direction});
}

class ToggleResultsIntent extends Intent {
  const ToggleResultsIntent();
}

class FormatDocumentIntent extends Intent {
  const FormatDocumentIntent();
}

class ToggleCommentIntent extends Intent {
  const ToggleCommentIntent();
}

class ZoomInIntent extends Intent {
  const ZoomInIntent();
}

class ZoomOutIntent extends Intent {
  const ZoomOutIntent();
}

class ResetZoomIntent extends Intent {
  const ResetZoomIntent();
}

class CompletionIntent extends Intent {
  const CompletionIntent();
}

class HelpIntent extends Intent {
  const HelpIntent();
}
