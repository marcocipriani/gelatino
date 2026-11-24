export 'media_disk_cache_stub.dart'
    if (dart.library.io) 'media_disk_cache_io.dart'
    if (dart.library.js_interop) 'media_disk_cache_web.dart'
    show createPlatformMediaDiskCache;
