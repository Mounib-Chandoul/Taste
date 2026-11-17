export 'store_base.dart';
export 'store_none.dart'
    if (dart.library.io) 'store_io.dart'
    if (dart.library.html) 'store_web.dart';
