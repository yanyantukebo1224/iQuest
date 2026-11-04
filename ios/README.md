# iQuest iOS bring-up (iPhone 16e)

This is the iOS-native frontend and hardware-input bring-up for the iQuest/Klepton port.

## Current iOS app shell

- iOS 18+ ARM64 app scaffold.
- Full-screen Quest game-library launcher; the old tracking/debug HUD is no longer shown.
- Import picker accepts a single `.apk` file and retains its security-scoped URL while selected.
- The display idle timer is disabled while iQuest is active in the foreground and restored when it is backgrounded or closed.
- The previous ARKit/Vision/GameController prototype sources remain in the project for later connection to the guest runtime, but are not presented as a dashboard.

## Important: APK selection is not game execution

The launcher currently selects an APK and shows its filename. It does not yet parse Android package metadata, extract APK/split-APK contents, start an Android guest process, or render a Quest game. The Start game action deliberately reports that the Klepton iOS guest runtime is not linked instead of pretending a game launched.

The current iOS Xcode target builds the Swift app shell only. The existing Klepton C runtime and graphics/XR sources have not yet been compiled into an iOS framework or connected to this app. This is the next major implementation task.

## Existing tracking/input prototype (not currently in the launcher UI)

- ARKit world tracking and camera 6DoF pose.
- ARSCNView camera passthrough scene.
- Vision `VNDetectHumanHandPoseRequest` for up to two hands and the 21 standard hand landmarks.
- Approximate world-space joint coordinates using camera intrinsics and an estimated palm-width depth.
- GameController extended-gamepad button and stick input.
- Controller IMU data is not read or used.

Vision supplies 2D image landmarks, not true per-joint depth. The current 3D reconstruction estimates one depth per hand from an assumed palm width and projects the 2D joints through the AR camera intrinsics. It is a prototype, not Quest-grade 3D hand tracking. Occlusion, hand rotation, unusual hand sizes, lighting, and motion blur affect accuracy. The iPhone 16e has no LiDAR, so this app does not claim sensor-based hand depth or Quest 3-style depth-aware passthrough.

The camera passthrough is a single rear-camera view. It is not true stereo passthrough, and it does not reproduce Quest 3's stereo/depth occlusion.

## Controller scope

The app's existing input prototype listens for GameController devices that expose an extended gamepad profile. It forwards sticks, face buttons, shoulders, triggers, menu/options/home and D-pad states. It does not yet emulate Touch controller-specific haptics, capacitive touch sensors, per-controller pose tracking, or a complete Android input-device API. Joy-Con compatibility must be verified on the actual paired devices and iOS version.

Controller position and orientation are intended to come from camera-based hand tracking, never from the Joy-Con IMU. That pose-to-Quest-input bridge is not yet connected to the native guest runtime.

## Runtime work required before a game can launch

1. Build the required Klepton C/Objective-C runtime sources for iOS arm64 and resolve platform-specific Darwin/iOS differences.
2. Add an iOS runtime bridge with a defined guest lifecycle API (load, initialize, run, pause, stop, unload) and structured error reporting.
3. Implement APK and split-APK ingestion: package metadata, ABI selection, native library/resource extraction, asset paths, and guest storage mapping.
4. Connect the translated ARM64 guest libraries and required Bionic/JNI/Android compatibility layers to the iOS runtime.
5. Bring up GLES through ANGLE/Metal and/or Vulkan through MoltenVK, then connect the guest EGL/OpenXR/OVRP paths to an iOS compositor.
6. Render a real guest frame before wiring ARKit head pose, camera-based hands, and controller actions into the guest XR/input APIs.

Compatibility is not universal: Klepton's documented runtime path has limitations around Java/ART/JVM-heavy applications. Unity/IL2CPP Quest titles still need the Android framework and XR compatibility surface they depend on. APK selection alone cannot make an arbitrary Quest APK runnable.

## Build on macOS

Requirements: Apple Silicon Mac, Xcode with iOS 18 SDK, and XcodeGen.

```bash
brew install xcodegen
make ios-project
make ios
```

Or directly:

```bash
xcodegen generate --spec ios/project.yml --project ios/iQuest.xcodeproj
xcodebuild -project ios/iQuest.xcodeproj \
  -scheme iQuest -sdk iphoneos \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/ios/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

The GitHub Actions workflow builds an unsigned device app. A signed build and valid provisioning profile are required for installation on a physical iPhone.
