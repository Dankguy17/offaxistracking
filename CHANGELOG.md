# CHANGELOG

## 2026-04-18
- Scaffolded the native macOS SwiftUI application, Xcode project, and unit test target.
- Created the architecture-aligned source directory layout and initial root view.
- Added repository basics with `.gitignore` and an initial `README.md`.
- Reason: establish a buildable baseline before implementing camera, tracking, and rendering systems.
- Added the first real app-state layer with shared pose/tracking/calibration models and persisted calibration storage in Application Support.
- Reworked the SwiftUI shell into a split playground layout with camera, renderer, and inspector panels plus live calibration/debug controls.
- Added a calibration profile round-trip unit test to lock down persistence behavior before camera/tracking integration.
- Reason: establish the non-rendering architecture and operator-facing controls before wiring the camera and Vision pipelines.
