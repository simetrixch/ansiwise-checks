import 'package:ansiwise_checks_tree/audits.dart';

/// captured-refusal — a capture never answers, on a reading that was refused, a value its undo
/// ACTS on.
///
/// A capture has no "more work" direction. Every value it answers is an instruction to the undo —
/// one half leaves the machine as it stands, the other takes something away — and a refusal folded
/// here issues the taking-away over a machine nobody could read, while the engine is cleaning up
/// after some other step failed. Three sites cost this platform exactly that: a membership, a tag
/// somebody else published, and a credential every workload reading it depends on.
///
/// This package holds no capture of its own, so the numbers the audit states over it are zero and
/// say so. What the run proves here is the SCAN: every counter-probe plants a shape the sweep found
/// and an innocent neighbour from the same taxonomy beside it.
void main() => auditCapturedRefusal(scannedPaths: <String>['lib']);
