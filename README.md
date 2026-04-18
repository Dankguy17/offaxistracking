# Head-Tracked macOS 3D Window Playground

Prototype macOS application for experimenting with webcam-based head tracking and off-axis 3D projection.

## Current Status

Native Xcode macOS app scaffold with an end-to-end prototype slice in place:

- persistent calibration profile storage in Application Support
- shared tracking, pose, projection, and debug models
- split SwiftUI layout for camera, renderer, and inspector panels
- projection freeze and calibration controls wired into app state
- live built-in webcam capture through `AVFoundation`
- embedded camera preview surface in the playground UI
- Vision-powered single-face acquisition, box tracking, and landmark overlay
- coarse face-box fallback when landmarks temporarily disappear
- raw and smoothed head-pose estimation for `x`, `y`, and approximate `z`
- MetalKit renderer with a readable 3D workspace scene: room shell, floor grid, desk, monitor, shelving, and props
- real-time off-axis projection updates driven by the smoothed head pose
- debug freeze mode that holds the applied projection steady while tracking continues live

## Requirements

- macOS 15 or newer
- Xcode 26.0 or newer

## Build

1. Open `HeadTrackedPlayground.xcodeproj` in Xcode.
2. Build the `HeadTrackedPlayground` scheme.
3. Run the app on macOS.

On first launch, the app requests macOS camera permission and starts the webcam preview automatically.
Once a face is acquired, the app tracks a single primary face between frames, overlays the tracked face box plus available landmark strokes on the preview, and keeps coarse pose tracking alive briefly if landmarks drop out.
The Metal viewport renders a small workspace room with live off-axis projection driven by the smoothed pose values from the inspector.
Enable `Freeze Projection` in the inspector to hold the currently applied scene projection steady while pose values and tracking debug output continue updating.

## Notes

- The renderer uses Metal / MetalKit directly and does not depend on SceneKit.
- Shader source is compiled at runtime from an embedded Metal source string instead of a checked-in `.metal` build phase input. This keeps command-line builds working on systems where Xcode's optional Metal Toolchain component is not installed.

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
