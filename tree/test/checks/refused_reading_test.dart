import 'package:ansiwise_checks_tree/audits.dart';

/// refused-reading — a step never answers SATISFIED on a reading that was refused.
///
/// A reading that COULD NOT BE TAKEN is turned into an answer: "the tool did not answer" comes back
/// looking exactly like "there is nothing there". A measurement that folds a refused reading into
/// the null that means "this machine steers nothing" carries every step hung off it, and each one
/// answers Satisfied over a machine nobody measured.
///
/// This package makes no reading of its own, so the numbers the audit states over it are zero and
/// say so. What the run proves here is the SCAN: every counter-probe plants a shape this catches
/// and an innocent neighbour from the same taxonomy beside it.
void main() => auditRefusedReading(scannedPaths: <String>['lib']);
