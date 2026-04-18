# AGENTS.md

## Project
Head-Tracked macOS 3D Window Playground

## Mission
Build a macOS test playground application that uses the built-in webcam to track the user’s face/head and render a simple 3D scene with off-axis projection so the world appears to remain stable behind the display as the user moves.

This is a prototype and research playground, not a production eye-tracking product. Prioritize a convincing head-tracked parallax illusion, low latency, clean architecture, and debuggability.

---

## Non-Negotiable Requirements

1. Use:
   - Swift
   - SwiftUI
   - AVFoundation
   - Vision
   - Metal / MetalKit

2. Do **not** use SceneKit as the core rendering stack.

3. Keep the app buildable after every change.

4. Commit after **every change** with a clear commit message.

5. Maintain a comprehensive `CHANGELOG.md`.
   - If `CHANGELOG.md` does not exist, create it immediately.
   - Update it after every meaningful change.
   - Log what changed, why, and any important implementation notes.

6. Keep `README.md` current enough that a new developer can build and run the app.

7. Prefer small, modular, testable components over monolithic files.

---

## Product Goal

Create a “head-tracked 3D window” effect:
- Webcam captures the user
- Vision detects and tracks the face and key facial landmarks
- App estimates head position relative to the display
- Renderer applies off-axis projection so the 3D world updates as the user moves

Important:
- Build for **head tracking first**
- Treat gaze/eye tracking as optional or experimental
- A stable approximation is better than an unstable “advanced” system

---

## MVP Scope

### Required MVP Features
1. Live webcam preview
2. Face detection
3. Landmark overlay
4. Smoothed estimated head pose:
   - horizontal offset (`x`)
   - vertical offset (`y`)
   - approximate depth/distance (`z`)
5. Simple 3D scene:
   - room, grid, or floating primitives
6. Real-time off-axis projection
7. Calibration UI:
   - monitor size
   - webcam location/offset
   - neutral head position
8. Debug UI:
   - current pose values
   - confidence
   - tracking state
   - frame/update timing if practical

### Explicitly Out of Scope for First Pass
- Production-grade eye tracking
- Multi-user support
- Advanced photoreal graphics
- Cross-platform support
- AR headset integration
- Over-engineered settings menus

---

## Preferred Architecture

Use a modular structure resembling:

- `App/`
  - app entry
  - app state
- `UI/`
  - SwiftUI screens
  - debug panels
  - calibration panels
- `Camera/`
  - `CameraCaptureService`
- `Tracking/`
  - `FaceTrackingService`
  - landmark extraction
- `Pose/`
  - `PoseEstimator`
  - smoothing filters
- `Calibration/`
  - `CalibrationManager`
  - monitor/camera geometry
- `Projection/`
  - `ProjectionEngine`
  - off-axis math
- `Rendering/`
  - `MetalRenderer`
  - shaders
  - scene data
- `Models/`
  - shared structs, config, state, math types
- `Utilities/`
  - logging
  - timing
  - helpers

You may adapt naming if needed, but preserve separation of concerns.

---

## System Design Guidance

### 1. Camera Input
Use `AVFoundation` to obtain frames from the built-in webcam with predictable timing and minimal overhead.

### 2. Face Tracking
Use `Vision` for:
- face detection
- face tracking
- 2D landmarks

Track a single primary face only.

### 3. Pose Estimation
Estimate head position from:
- face bounding box center
- eye landmarks
- inter-eye distance or face box size for approximate depth

This is an inferred head pose, not precise 3D face mesh tracking. Design accordingly.

### 4. Smoothing
Tracking will be noisy. Include smoothing from the start.
Acceptable options:
- exponential smoothing
- low-pass filtering
- One Euro style smoothing
- lightweight Kalman-style smoothing if justified

Prefer something simple and maintainable first.

### 5. Calibration
Include a calibration flow that lets the user define:
- screen dimensions
- webcam relative position
- neutral center position
- optional distance baseline

Store calibration cleanly.

### 6. Projection
Implement true off-axis projection math rather than fake camera panning.
The display should be modeled as a physical viewing window into the virtual world.

### 7. Rendering
Use Metal / MetalKit for:
- simple geometry
- camera/view/projection updates
- stable frame rendering

Keep first scene intentionally simple and useful for parallax judgment.

---

## Implementation Priorities

Implement in this order unless a better dependency order becomes obvious:

### Phase 1 — Project Skeleton
- Create project structure
- Create base app shell
- Set up webcam capture
- Set up Metal view
- Create `CHANGELOG.md`
- Create/update `README.md`

### Phase 2 — Tracking Vertical Slice
- Face detection and tracking
- Landmark extraction
- Overlay on webcam preview
- Tracking state display

### Phase 3 — Pose Estimation
- Estimate `x`, `y`, `z`
- Add smoothing
- Add confidence handling
- Add tracking loss fallback behavior

### Phase 4 — 3D Rendering
- Simple scene
- Camera controls
- Real-time projection updates
- Visible parallax effect

### Phase 5 — Calibration
- UI and data model
- Save/load calibration
- Apply calibration to projection pipeline

### Phase 6 — Debugging and Polish
- Debug panels
- timing/latency info
- better visuals
- code cleanup
- docs cleanup

---

## Code Quality Standards

1. Code must be readable and intentionally structured.
2. Use descriptive naming.
3. Comment non-obvious math and rendering logic.
4. Avoid giant view files and giant manager classes.
5. Avoid unnecessary abstractions early, but do not allow architectural collapse.
6. Keep public interfaces clean and focused.
7. Prefer deterministic behavior and explicit state flow.

---

## Git Workflow Rules

You must commit after **every change**.

Rules:
- Make a git commit after each meaningful file change or small grouped change
- Use clear messages
- Do not batch huge unrelated changes into one commit
- Keep the repository in a working state at all times

Suggested commit style:
- `init: scaffold macOS head-tracked playground`
- `feat: add AVFoundation webcam capture service`
- `feat: add Vision face tracking and landmark overlay`
- `feat: estimate head pose from face landmarks`
- `feat: implement off-axis projection engine`
- `feat: add calibration manager and UI`
- `fix: smooth jitter in pose estimation`
- `docs: update README and CHANGELOG`

If you hit a blocker, still commit the safe intermediate state with an honest message.

---

## CHANGELOG.md Rules

`CHANGELOG.md` is mandatory.

If missing:
- create it immediately

After every meaningful change:
- add an entry

Each entry should include:
- date/time if practical
- summary of change
- files/components affected
- reason for change
- follow-up notes if relevant

Be specific. The changelog should help someone understand the project’s evolution without reading every commit.

Suggested format:

```md
# CHANGELOG

## 2026-04-18
- Scaffolded app shell with SwiftUI root view and Metal rendering surface.
- Added AVFoundation webcam capture pipeline.
- Created initial project folders and service boundaries.
- Reason: establish end-to-end foundation for tracking + rendering.

README.md Expectations

Keep the README useful throughout development.

It should eventually include:

project overview
current status
architecture summary
build/run instructions
permissions needed (camera)
known limitations
roadmap
calibration notes
UI / UX Expectations

The app is a playground, so prioritize utility over beauty.

Include:

main 3D viewport
webcam preview
landmark overlay
calibration controls
debug panel

The UI should make it easy to tell:

whether tracking is active
what pose is being estimated
whether calibration is applied
whether the renderer is responding correctly
Handling Limitations

Be honest in the code and docs:

webcam-based tracking is approximate
eye tracking on normal Mac webcams is limited
the main goal is stable head-tracked perspective

Do not fake precision claims.

Performance Expectations

Prioritize:

low latency
stable frame updates
low jitter
graceful degradation when tracking confidence drops

Avoid expensive or premature complexity.

If needed:

decouple tracking update loop from rendering loop
smooth pose values before applying them to projection
use a debug mode to inspect timing
Testing Expectations

At minimum, validate:

App launches cleanly
Camera permission flow works
Webcam frames appear
Face is detected
Landmarks render
Pose values change sensibly with motion
Projection visibly responds to head movement
Tracking loss does not break the renderer
Calibration changes affect projection

Add lightweight tests where practical for math-heavy utilities and projection calculations.

Documentation Expectations

Document:

how head pose is estimated
how calibration maps real-world screen geometry to the renderer
how off-axis projection works at a high level
current limitations and assumptions

Any nontrivial math should be explained in comments and/or docs.

Decision Heuristics

When unsure:

Choose the simpler implementation that preserves architectural clarity
Prefer stable head tracking over ambitious eye tracking
Prefer explicit math and control over opaque convenience frameworks
Prefer a working vertical slice over wide but unfinished scaffolding
Keep the result easy for a human developer to continue
First Execution Checklist

Start by doing these immediately:

Inspect repo state
Create CHANGELOG.md if absent
Update/create README.md if needed
Scaffold project structure
Create basic SwiftUI app shell
Add Metal rendering surface
Add webcam capture service
Commit
Continue iteratively, committing after every change
Final Deliverable Standard

A good result is:

buildable
documented
modular
committed incrementally
includes a real tracking-to-rendering pipeline
demonstrates convincing head-tracked parallax in a simple 3D scene

Ship the simplest version that proves the core illusion well.