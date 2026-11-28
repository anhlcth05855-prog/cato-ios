import SwiftUI

/// Màn hình chính điều phối toàn bộ hệ thống Cato trên iOS
public struct MainView: View {

    @StateObject private var distanceEstimator = DistanceEstimator()
    @StateObject private var thresholdManager = SafetyThresholdManager()
    @StateObject private var soundManager = AlertSoundManager.shared
    @StateObject private var voiceManager = VoiceAlertManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var speedLimitManager = RoadSpeedLimitManager.shared
    @StateObject private var tiltSensor = TiltSensorManager.shared
    @StateObject private var historyManager = TripHistoryManager.shared
    @StateObject private var cameraFeed = CameraFeedManager.shared

    @State private var currentMode: HUDOverlayView.ViewMode = .camera
    @State private var vehicles: [DetectedVehicle] = []
    @State private var assessment: SafetyAssessment = SafetyAssessment()

    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var showingDisclaimer = false

    // Mô phỏng khoảng cách khi chạm vào sơ đồ
    @State private var simulatedTouchDistance: Float? = nil
    @State private var simulationTimer: Timer? = nil

    public init() {}

    public var body: some View {
        ZStack {
            // Nền đen sâu
            Color(red: 10/255, green: 12/255, blue: 16/255)
                .ignoresSafeArea()

            // 1. Chế độ hiển thị chính
            switch currentMode {
            case .camera:
                CameraView(
                    vehicles: vehicles,
                    assessment: assessment,
                    onTouchDistanceSelected: { dist in
                        simulatedTouchDistance = dist
                        updateInferenceLoop(overrideDistance: dist)
                    }
                )
                .ignoresSafeArea()

            case .schematic:
                SchematicView(
                    vehicles: vehicles,
                    assessment: assessment,
                    onTouchDistanceSelected: { dist in
                        simulatedTouchDistance = dist
                        updateInferenceLoop(overrideDistance: dist)
                    }
                )
                .ignoresSafeArea()

            case .screenOff:
                ScreenOffView(assessment: assessment) {
                    currentMode = .schematic
                }
                .ignoresSafeArea()
            }

            // 2. Lớp giao diện HUD (ẩn ở chế độ Tắt màn hình)
            if currentMode != .screenOff {
                HUDOverlayView(
                    thresholdManager: thresholdManager,
                    assessment: assessment,
                    vehicles: vehicles,
                    currentSpeed: locationManager.currentSpeedKmh,
                    speedLimitKmh: speedLimitManager.currentSpeedLimitKmh,
                    nearbyCameraMeters: speedLimitManager.nearbySpeedCameraDistanceMeters,
                    isMuted: soundManager.isMuted,
                    isSimulatingTouch: simulatedTouchDistance != nil,
                    currentMode: currentMode,
                    onToggleMute: {
                        soundManager.isMuted.toggle()
                    },
                    onOpenHistory: {
                        showingHistory = true
                    },
                    onOpenSettings: {
                        showingSettings = true
                    },
                    onSelectMode: { mode in
                        if mode == .camera {
                            simulatedTouchDistance = nil
                        }
                        currentMode = mode
                    },
                    onQuickTestDistance: { dist in
                        simulatedTouchDistance = dist
                        if let dist = dist {
                            updateInferenceLoop(overrideDistance: dist)
                        } else {
                            syncSimulationState()
                        }
                    }
                )
            }
        }
        .onAppear {
            setupSystem()
        }
        .onChange(of: locationManager.isDemoMode) { _ in
            syncSimulationState()
        }
        .onChange(of: cameraFeed.isAuthorized) { _ in
            syncSimulationState()
        }
        .onChange(of: cameraFeed.isCameraAvailable) { _ in
            syncSimulationState()
        }
        .sheet(isPresented: $showingHistory) {
            TripHistoryView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                distanceEstimator: distanceEstimator,
                thresholdManager: thresholdManager
            )
        }
        .sheet(isPresented: $showingDisclaimer) {
            DisclaimerView()
        }
    }

    private func setupSystem() {
        // Khởi động các cảm biến & dịch vụ vị trí
        locationManager.requestPermission()
        locationManager.start()
        tiltSensor.start()

        // Liên kết cảm biến độ nghiêng với bộ ước lượng khoảng cách
        tiltSensor.onPitchChanged = { pitch in
            DispatchQueue.main.async {
                self.distanceEstimator.pitchAngleRad = pitch
            }
        }

        // Liên kết vị trí GPS với quản lý lộ trình & giới hạn tốc độ
        locationManager.onLocationUpdated = { location, speed, roadName in
            self.historyManager.recordPoint(
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude,
                speedKmh: speed,
                roadName: roadName
            )
            self.speedLimitManager.update(location: location, speedKmh: speed, isDemoMode: self.locationManager.isDemoMode)
            self.voiceManager.evaluateOverspeed(
                speedKmh: speed,
                limitKmh: self.speedLimitManager.currentSpeedLimitKmh,
                isMuted: self.soundManager.isMuted
            )
            self.voiceManager.evaluateSpeedCamera(
                distanceMeters: self.speedLimitManager.nearbySpeedCameraDistanceMeters,
                isMuted: self.soundManager.isMuted
            )
            self.updateInferenceLoop()
        }

        // Liên kết luồng khung hình camera với AI nhận diện xe
        cameraFeed.onFrameCaptured = { pixelBuffer in
            guard self.simulatedTouchDistance == nil, !self.locationManager.isDemoMode else { return }

            VehicleDetector.shared.detect(pixelBuffer: pixelBuffer) { detected in
                DispatchQueue.main.async {
                    guard self.simulatedTouchDistance == nil, !self.locationManager.isDemoMode else { return }
                    let processed = self.distanceEstimator.processVehicles(
                        vehicles: detected,
                        currentSpeedKmh: self.locationManager.currentSpeedKmh
                    )
                    self.vehicles = processed
                    self.evaluateSafety(processedVehicles: processed)
                }
            }
        }

        syncSimulationState()
    }

    private func syncSimulationState() {
        let shouldSimulate = locationManager.isDemoMode || !cameraFeed.isCameraAvailable
        if shouldSimulate {
            guard simulationTimer == nil else { return }
            simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if self.simulatedTouchDistance == nil {
                    let simVehicles = VehicleDetector.shared.generateSimulatedVehicles(leadDistance: 48.0)
                    let processed = self.distanceEstimator.processVehicles(
                        vehicles: simVehicles,
                        currentSpeedKmh: self.locationManager.currentSpeedKmh
                    )
                    self.vehicles = processed
                    self.evaluateSafety(processedVehicles: processed)
                }
            }
        } else {
            simulationTimer?.invalidate()
            simulationTimer = nil
            if simulatedTouchDistance == nil {
                vehicles = []
                evaluateSafety(processedVehicles: [])
            }
        }
    }

    private func updateInferenceLoop(overrideDistance: Float? = nil) {
        let speed = locationManager.currentSpeedKmh
        let dist = overrideDistance ?? vehicles.first(where: { $0.isLeadVehicle })?.distanceMeters ?? 0

        if let overrideDist = overrideDistance {
            let simVehicles = VehicleDetector.shared.generateSimulatedVehicles(leadDistance: overrideDist)
            self.vehicles = self.distanceEstimator.processVehicles(vehicles: simVehicles, currentSpeedKmh: speed)
        }

        let newAssessment = thresholdManager.evaluate(distanceMeters: dist, speedKmh: speed)
        self.assessment = newAssessment
        soundManager.updateAlertState(level: newAssessment.alertLevel)
        voiceManager.evaluateDistanceAlert(level: newAssessment.alertLevel, speedKmh: speed, isMuted: soundManager.isMuted)
    }

    private func evaluateSafety(processedVehicles: [DetectedVehicle]) {
        let lead = processedVehicles.first(where: { $0.isLeadVehicle })
        let dist = lead?.distanceMeters ?? 0
        let speed = locationManager.currentSpeedKmh

        let newAssessment = thresholdManager.evaluate(distanceMeters: dist, speedKmh: speed)
        self.assessment = newAssessment
        soundManager.updateAlertState(level: newAssessment.alertLevel)
        voiceManager.evaluateDistanceAlert(level: newAssessment.alertLevel, speedKmh: speed, isMuted: soundManager.isMuted)
    }
}
