import 'package:readytech/bootstrap.dart';

/// Single entry point for every flavor.
///
/// The flavor is chosen at build time through `--dart-define-from-file`, not by
/// a separate `main_dev.dart` / `main_prod.dart` file. One entry point means
/// there is no chance of a production build accidentally starting the file that
/// points at sandbox payment credentials.
void main() => bootstrap();
