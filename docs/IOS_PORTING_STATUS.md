# iQuest iOS port status

## Source archive inspected

The supplied archive is Klepton snapshot `1fe7e6caf6bb8bc90c1a5e61d5b9bfc6e110fa32` (2026-10-22). Its `BUILDING.md` documents macOS Apple Silicon and visionOS builds. The root `Makefile` has `angle-ios` and `angle-ios-sim` targets, but those are intermediate ANGLE builds used by `angle-xros` / `angle-xrsim`; they are not an iOS Klepton app target. More importantly, `tools/klepton_ld.c` already recognizes `--platform ios` and `--platform iossim` (minimum iOS 17.0), so the offline ELF-to-Mach-O translator has an iOS platform stamp. That is reusable groundwork, not proof that the complete runtime runs on iOS.

The visionOS frontend in `visionos/Sources` imports `CompositorServices` and uses `LayerRenderer`. That compositor cannot be reused as an iOS app compositor. The shared C runtime and guest loader are the likely reuse boundary, but need an iOS SDK compile/link audit before being added to an iOS target.

## Added in this branch

- `ios/project.yml`: XcodeGen project definition for an iOS 18 app.
- `ios/Sources`: ARKit world-tracking proof of concept displaying camera pose and tracking state.
- `ios/mkguest.sh`: offline-translates the selected target's native `.so` files into iOS-stamped frameworks using the existing `klepton-ld --platform ios` path. Embedding/signing those frameworks is not wired into the iOS app target yet.
- `.github/workflows/ios-build.yml`: unsigned iOS device-SDK build on a macOS GitHub runner.
- `make ios-project` and `make ios`: local build entry points.

## Next engineering gates

1. Run the iOS build gate on macOS and fix SDK/API availability issues.
2. Add a minimal iOS Metal stereo renderer with two eye views and a configurable IPD.
3. Port only the required Klepton runtime C sources into an iOS static library; resolve every iOS-unavailable symbol at link time.
4. Add a prelinked guest-library packaging format compatible with iOS code signing and the app bundle. Do not rely on runtime-generated executable pages.
5. Implement an iOS XR backend for the subset of OpenXR/OVRP used by a selected test APK.
6. Add input and hand-tracking capabilities only after validating iPhone 16e camera geometry and ARKit/Vision support.

## Platform constraints to keep explicit

- ESign changes signing/installation; it does not grant Apple's private dynamic-code-signing entitlement or make JIT available.
- AOT/prelinked guest code may be feasible, but the current `klepton-ld` runtime behavior must be audited for runtime writes/patches and executable mappings before claiming JIT-less iOS support.
- ARKit world tracking provides visual-inertial pose estimation, not the same tracking volume, prediction, controllers, or compositor guarantees as Quest 3.
- iPhone 16e has no LiDAR depth sensor. Hand tracking is not supplied by the ARKit hand-skeleton APIs available on visionOS; any iPhone implementation needs a camera/Vision-based design and will have field-of-view/occlusion constraints.
