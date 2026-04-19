import SwiftUI

struct InspectorPanel: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Calibration & Debug")
                    .font(.title2.weight(.semibold))

                GroupBox("Tracking State") {
                    LabeledContent("Mode", value: appModel.trackingStatus.mode.rawValue)
                    LabeledContent("Confidence", value: appModel.trackingStatus.confidence.formatted(.number.precision(.fractionLength(2))))
                    LabeledContent("Fallback", value: appModel.isUsingCoarseFallback ? "Coarse face box" : "Landmarks")
                    LabeledContent("Age", value: "\(appModel.trackingStatus.lastUpdateAge.formatted(.number.precision(.fractionLength(3)))) s")
                }

                GroupBox("Pose") {
                    LabeledContent("Raw X", value: metric(appModel.rawPose.x))
                    LabeledContent("Raw Y", value: metric(appModel.rawPose.y))
                    LabeledContent("Raw Z", value: metric(appModel.rawPose.z))
                    Divider()
                    LabeledContent("Smooth X", value: metric(appModel.smoothedPose.x))
                    LabeledContent("Smooth Y", value: metric(appModel.smoothedPose.y))
                    LabeledContent("Smooth Z", value: metric(appModel.smoothedPose.z))
                }

                GroupBox("Display Calibration") {
                    Toggle("Mirror Webcam", isOn: $appModel.calibrationProfile.isWebcamMirrored)
                    NumericField(title: "Display Width (m)", value: $appModel.calibrationProfile.displayWidthMeters)
                    NumericField(title: "Display Height (m)", value: $appModel.calibrationProfile.displayHeightMeters)
                    NumericField(title: "Webcam X Offset (m)", value: $appModel.calibrationProfile.webcamOffsetXMeters)
                    NumericField(title: "Webcam Y Offset (m)", value: $appModel.calibrationProfile.webcamOffsetYMeters)
                    NumericField(title: "Webcam Z Offset (m)", value: $appModel.calibrationProfile.webcamOffsetZMeters)
                    NumericField(title: "Neutral Face X", value: $appModel.calibrationProfile.neutralFaceCenterX)
                    NumericField(title: "Neutral Face Y", value: $appModel.calibrationProfile.neutralFaceCenterY)
                    NumericField(title: "Baseline Eye Distance", value: $appModel.calibrationProfile.baselineInterEyeDistance)
                }

                GroupBox("Paper Auto-Calibration") {
                    Picker("Paper Size", selection: $appModel.paperCalibrationTarget) {
                        ForEach(PaperCalibrationTarget.allCases) { target in
                            Text(target.displayName)
                                .tag(target)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Hold the sheet near your face at your intended neutral position. Keeping both your face and the paper visible gives the best neutral depth capture.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    LabeledContent("State", value: appModel.paperCalibrationState.phase.rawValue.capitalized)

                    if let observation = appModel.paperCalibrationState.observation {
                        LabeledContent("Detected Sheet", value: observation.sheet.displayName)
                        LabeledContent("Estimated Distance", value: metric(observation.estimatedDistanceMeters))
                        LabeledContent("Stability", value: observation.stabilityProgress.formatted(.percent.precision(.fractionLength(0))))
                    }

                    Text(paperCalibrationInstructionText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if appModel.paperCalibrationState.isRunning {
                        Button("Cancel Auto-Calibration") {
                            appModel.cancelPaperCalibration()
                        }
                    } else {
                        Button("Auto-Calibrate with Paper") {
                            appModel.startPaperCalibration()
                        }
                    }
                }

                GroupBox("Tracking Tuning") {
                    NumericField(title: "Lateral Smoothing", value: $appModel.calibrationProfile.lateralSmoothing)
                    NumericField(title: "Depth Smoothing", value: $appModel.calibrationProfile.depthSmoothing)
                    NumericField(title: "Fallback Hold (s)", value: $appModel.calibrationProfile.fallbackHoldDuration)
                    NumericField(title: "Reacquire Interval", value: $appModel.calibrationProfile.reacquireInterval)
                }

                GroupBox("Scene") {
                    Picker("Environment", selection: $appModel.selectedEnvironment) {
                        ForEach(RenderEnvironment.allCases) { environment in
                            Text(environment.displayName)
                                .tag(environment)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Map an image onto a rear projection screen inside the active scene.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let artwork = appModel.environmentArtwork {
                        LabeledContent("Screen Image", value: artwork.displayName)
                    } else {
                        LabeledContent("Screen Image", value: "None")
                    }

                    HStack {
                        Button("Choose Image") {
                            appModel.chooseEnvironmentArtwork()
                        }

                        Button("Clear Image") {
                            appModel.clearEnvironmentArtwork()
                        }
                        .disabled(appModel.environmentArtwork == nil)
                    }
                }

                GroupBox("Debug") {
                    Toggle("Freeze Projection", isOn: $appModel.isProjectionFrozen)
                    LabeledContent("Vision Latency", value: "\(appModel.debugMetrics.visionLatencyMS.formatted(.number.precision(.fractionLength(1)))) ms")
                    LabeledContent("Camera FPS", value: appModel.debugMetrics.cameraFPS.formatted(.number.precision(.fractionLength(1))))
                    LabeledContent("Render FPS", value: appModel.debugMetrics.renderFPS.formatted(.number.precision(.fractionLength(1))))
                }

                HStack {
                    Button("Capture Neutral Pose") {
                        appModel.captureNeutralPose()
                    }

                    Button("Reset Calibration") {
                        appModel.resetCalibration()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(minWidth: 320, idealWidth: 340, maxWidth: 360)
        .background(
            Color.white.opacity(0.84)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: -4, y: 0)
        )
        .foregroundStyle(Color(red: 0.17, green: 0.18, blue: 0.19))
        .onChange(of: appModel.calibrationProfile) { _, _ in
            appModel.persistCalibration()
        }
    }

    private func metric(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(3)))
    }

    private var paperCalibrationInstructionText: String {
        if appModel.paperCalibrationState.phase == .idle {
            return appModel.paperCalibrationTarget.detectionPrompt
        }

        return appModel.paperCalibrationState.instructionText
    }
}

private struct NumericField: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: $value, format: .number.precision(.fractionLength(3)))
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
        }
    }
}
