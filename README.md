# Head-Tracked macOS 3D Window Playground

Prototype macOS application for experimenting with webcam-based head tracking and off-axis 3D projection.

## Current Status

Native Xcode macOS app scaffold with an end-to-end prototype slice in place:

- persistent calibration profile storage in Application Support
- shared tracking, pose, projection, and debug models
- split SwiftUI layout for camera, renderer, and inspector panels
- projection freeze and calibration controls wired into app state
- mirrored/unmirrored webcam toggle so preview, overlay, and horizontal pose math stay aligned with the active camera orientation
- paper-based neutral-depth auto-calibration using an A4 or 8.5 x 11 inch sheet as a known-size target
- live built-in webcam capture through `AVFoundation`
- embedded camera preview surface in the playground UI
- Vision-powered single-face acquisition, box tracking, and landmark overlay
- coarse face-box fallback when landmarks temporarily disappear
- raw and smoothed head-pose estimation for `x`, `y`, and approximate `z`
- MetalKit renderer with switchable environments: a shaded 3D workspace room, a target-tunnel scene with near-3D billboard objects, and a theater-screen auditorium view with an oversized screen for judging flat-image stability as distance changes
- optional custom screen artwork loaded from disk and projected onto a theater-style rear screen inside either Metal environment
- workspace room now includes a suspended demo object above the floor so floating depth cues are easy to judge during head motion
- real-time off-axis projection updates driven by the smoothed head pose
- inspector-based environment switcher for comparing parallax cues across scenes
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
The Metal viewport renders a switchable scene set with live off-axis projection driven by the smoothed pose values from the inspector.
Use the `Scene` control in the inspector to swap between the workspace room, the target tunnel, and the theater-screen auditorium environment.
Use `Choose Image` in the `Scene` section to place a picture on the in-scene rear projection screen. The renderer preserves the image aspect ratio and fits it within the screen bounds.
Enable `Freeze Projection` in the inspector to hold the currently applied scene projection steady while pose values and tracking debug output continue updating.
Use `Mirror Webcam` in the calibration inspector if your camera feed appears mirrored and horizontal motion feels inverted relative to the rendered scene.
Use `Auto-Calibrate with Paper` to estimate neutral viewer distance from a held-up A4 or US Letter sheet. The most reliable results come from holding the page near your face at your intended neutral position while keeping the full page visible to the webcam.

## Notes

- The renderer uses Metal / MetalKit directly and does not depend on SceneKit.
- Shader source is compiled at runtime from an embedded Metal source string instead of a checked-in `.metal` build phase input. This keeps command-line builds working on systems where Xcode's optional Metal Toolchain component is not installed.
- Paper auto-calibration estimates depth from the apparent size of a known paper rectangle plus the camera's field of view. It improves neutral `z` calibration, but it is still an approximation based on monocular webcam geometry.

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
