# iQuest iOS bring-up (iPhone 16e)

This directory is the first iOS-native milestone for the Klepton port. It is deliberately a small, independently buildable ARKit app rather than a claim that the Quest runtime has already been ported.

## What this milestone does

- Builds as an iOS 18+ ARM64 app.
- Starts `ARWorldTrackingConfiguration` and reads the AR camera's 6DoF transform.
- Displays position, quaternion orientation, tracking state and frame count.
- Requires no JIT and does not generate executable code at runtime.

## What it does not do yet

- It does not load APKs or Android `.so` files.
- It does not link `libklepton` or the current visionOS frontend.
- It does not implement a stereoscopic headset compositor.
- It does not implement OpenXR, OVRP, hand tracking, or passthrough composition.

Those are separate porting milestones. In particular, the current Klepton Swift frontend imports `CompositorServices`, and its eye compositor is built around `LayerRenderer`; that is a visionOS-specific frontend and cannot simply be compiled for iOS.

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

The GitHub Actions workflow performs the same unsigned device-SDK build. It is a compile artifact, not an installable signed IPA. Sign the resulting app with a certificate/profile appropriate to your own device before installation.

## Offline guest-library translation (macOS host)

The upstream `klepton-ld` already accepts `--platform ios` (minimum iOS 17.0). After unpacking a legally obtained target APK into the directory expected by `visionos/targets.py`, translate its native libraries with:

```bash
make build/klepton-ld
KLEPTON_TARGET=<target-name> ios/mkguest.sh
```

This writes iOS-stamped `.framework` bundles under `ios/Frameworks/<target>/`. They are not yet embedded into the app target by this scaffold; the next porting step is to generate Xcode embed/sign phases and connect the runtime's bundle lookup to that directory.

## Device test

Install a signed build on iPhone 16e, grant camera permission, and check that `Tracking: normal` appears after looking around a textured, well-lit room. The app reports ARKit's camera pose; it does not claim headset-grade tracking or optical hand tracking.
