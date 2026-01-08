# Aether Client SDK for Flutter & Android

This SDK provides a wrapper around the Aether High-Performance VPN Core (Go), allowing you to run it inside a Flutter or Native Android application.

## Prerequisites

- Go 1.22+
- `gomobile` installed:
  ```bash
  go install golang.org/x/mobile/cmd/gomobile@latest
  gomobile init
  ```
- Android SDK & NDK

## Installation

1. **Build the Android Library (`.aar`)**:
   Run the following command from the root of the `Aether` project:
   ```bash
   make client-android
   ```
   This will generate `sdk/flutter/aether_client/android/libs/aether.aar`.

2. **Add to Flutter Project**:
   Add the local path to your app's `pubspec.yaml`:
   ```yaml
   dependencies:
     aether_client:
       path: ../path/to/Aether/sdk/flutter/aether_client
   ```

## Usage (Flutter)

```dart
import 'package:aether_client/aether_client.dart';

// 1. Define Config
String config = '''{
  "uuid": "YOUR_UUID",
  "server_addr": "1.2.3.4:443",
  "transport": "auto",
  "enable_dark_matter": true,
  "dark_matter_secret": "..."
}''';

// 2. Start VPN Core
try {
  await AetherClient.start(config);
  print("VPN Started!");
} catch (e) {
  print("Error: $e");
}

// 3. Get Stats
String stats = await AetherClient.getStats();
print(stats);

// 4. Stop
await AetherClient.stop();
```

## Usage (Desktop: Windows & macOS)

For Desktop platforms, this plugin uses **Dart FFI** to communicate directly with the compiled Go C-Shared library (`.dll` or `.dylib`).

1. **Build the Shared Library**:
   ```bash
   # macOS
   make client-desktop-mac
   # Windows
   make client-desktop-win
   ```
   This places `libaether.dylib` or `aether.dll` into `windows/libs` or `macos/libs` of the plugin.

2. **Run Flutter**:
   Just run as normal:
   ```bash
   flutter run -d macos
   flutter run -d windows
   ```

## Usage (Native Kotlin)

If you are using this in a pure Android app (no Flutter), you can use the `.aar` directly:

1. Import `aether.aar` into your Android Studio project.
2. Call the Go functions:
   ```kotlin
   import aether.Aether

   Aether.start(configJson)
   ```
