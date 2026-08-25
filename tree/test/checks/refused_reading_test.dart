import 'package:ansiwise_checks_tree/audits.dart';

/// refused-reading — a step never answers SATISFIED on a reading that was refused.
///
/// A reading that COULD NOT BE TAKEN is turned into an answer: "the tool did not answer" comes back
/// looking exactly like "there is nothing there". One measurement folded three refused readings into
/// the null that means "this machine steers nothing", eight steps hung off it, and all eight
/// answered Satisfied over a machine nobody had measured.
///
/// This package makes no reading of its own, so the numbers the audit states over it are zero and
/// say so. What the run proves here is the SCAN: every counter-probe plants a shape the sweep found
/// and an innocent neighbour from the same taxonomy beside it.
void main() => auditRefusedReading(scannedPaths: <String>['lib']);
