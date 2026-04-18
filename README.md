# Head-Tracked macOS 3D Window Playground

Prototype macOS application for experimenting with webcam-based head tracking and off-axis 3D projection.

## Current Status

Native Xcode macOS app scaffold with the first application-state layer in place:

- persistent calibration profile storage in Application Support
- shared tracking, pose, projection, and debug models
- split SwiftUI layout for camera, renderer, and inspector panels
- projection freeze and calibration controls wired into app state
- live built-in webcam capture through `AVFoundation`
- embedded camera preview surface in the playground UI
- Vision-powered single-face acquisition, box tracking, and landmark overlay
- coarse face-box fallback when landmarks temporarily disappear

## Requirements

- macOS 15 or newer
- Xcode 26.0 or newer

## Build

1. Open `HeadTrackedPlayground.xcodeproj` in Xcode.
2. Build the `HeadTrackedPlayground` scheme.
3. Run the app on macOS.

The current shell launches without camera or rendering active yet, but the calibration/debug UI is live and persists its settings across launches.
The camera preview now starts on launch and requests macOS camera permission if needed.
Once a face is acquired, the app tracks a single primary face between frames and overlays the tracked face box plus available landmark strokes on the preview.

## Planned Architecture

- `App/`
- `UI/`
- `Camera/`
- `Tracking/`
- `Pose/`
- `Calibration/`
- `Projection/`
- `Rendering/`
- `Models/`
- `Utilities/`
