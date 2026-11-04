# iQuest iOS bring-up (iPhone 16e)

This is the iOS-native frontend and hardware-input bring-up for the iQuest/Klepton port. The current branch adds an ARKit camera passthrough scene, Vision hand landmarks, a monocular 3D hand-position estimate, and a GameController input bridge.

## Implemented in this milestone

- iOS 18+ ARM64 app scaffold.
- ARKit world tracking and camera 6DoF pose.
- ARSCNView camera passthrough with a world-locked demo object.
- Vision `VNDetectHumanHandPoseRequest` for up to two hands and the 21 standard hand landmarks.
- Approximate world-space joint coordinates using camera intrinsics and an estimated palm-width depth.
- GameController extended-gamepad button and stick input.
- Controller IMU data is not read or used.

## Important tracking limitation

Vision supplies 2D image landmarks, not true per-joint depth. The current 3D reconstruction estimates one depth per hand from an assumed palm width and projects the 2D joints through the AR camera intrinsics. It is a working prototype, not Quest-grade 3D hand tracking. Occlusion, hand rotation, unusual hand sizes, lighting, and motion blur affect accuracy. The iPhone 16e has no LiDAR, so this app does not claim sensor-based hand depth or Quest 3-style depth-aware passthrough.

The camera passthrough is a single rear-camera view. It is not true stereo passthrough, and it does not reproduce Quest 3's stereo/depth occlusion. The current demo sphere is a world-locked MR composition test.

## Controller scope

The app listens for GameController devices that expose an extended gamepad profile. It forwards sticks, face buttons, shoulders, triggers, menu/options/home and D-pad states. It does not yet emulate Touch controller-specific haptics, capacitive touch sensors, per-controller pose tracking, or a complete Android input-device API. Joy-Con compatibility must be verified on the actual paired devices and iOS version.

Controller position and orientation are intended to come from camera-based hand tracking, never from the Joy-Con IMU. That pose-to-Quest-input bridge is not yet connected to the native guest runtime.

## Not implemented yet

- Quest APK ingestion, Android package/resource handling, and guest lifecycle.
- Embedding and loading the translated guest frameworks in the iOS app.
- A complete iOS port of Klepton's C runtime and its platform shims.
- GLES/ANGLE and Vulkan/MoltenVK device integration.
- OpenXR session/swapchain integration and the full OVRP compatibility surface.
- Touch-controller pose/action emulation and haptics.
- A production-quality 3D hand reconstruction, occlusion handling, and gesture-to-OpenXR action mapping.

The existing Klepton runtime is primarily built and validated for macOS and visionOS. Its current visionOS frontend depends on CompositorServices and cannot simply be compiled as an iOS frontend. The iOS port requires a separate compositor and platform layer.

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

## Device test

Install a signed build on iPhone 16e and grant camera permission. In a textured, well-lit room, verify that ARKit reaches `Tracking: normal`. Move one or both hands in front of the rear camera and check whether the dashboard reports hand detections and joint counts. Pair a supported controller in iOS Settings and check button/stick updates. The UI is a bring-up diagnostic, not yet a game launcher or a finished headset interface.
