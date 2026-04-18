# Head-Tracked macOS 3D Window Playground

Prototype macOS application for experimenting with webcam-based head tracking and off-axis 3D projection.

## Current Status

Native Xcode macOS app scaffold with the first application-state layer in place:

- persistent calibration profile storage in Application Support
- shared tracking, pose, projection, and debug models
- split SwiftUI layout for camera, renderer, and inspector panels
- projection freeze and calibration controls wired into app state

## Requirements

- macOS 15 or newer
- Xcode 26.0 or newer

## Build

1. Open `HeadTrackedPlayground.xcodeproj` in Xcode.
2. Build the `HeadTrackedPlayground` scheme.
3. Run the app on macOS.

The current shell launches without camera or rendering active yet, but the calibration/debug UI is live and persists its settings across launches.

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
