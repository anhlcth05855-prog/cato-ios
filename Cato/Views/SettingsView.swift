import SwiftUI
import UIKit

/// Màn hình Cài đặt thông số xe, camera và ngưỡng cảnh báo
public struct SettingsView: View {

    @ObservedObject var distanceEstimator: DistanceEstimator
    @ObservedObject var thresholdManager: SafetyThresholdManager
    @ObservedObject var soundManager = AlertSoundManager.shared
    @ObservedObject var voiceManager = VoiceAlertManager.shared
    @ObservedObject var locationManager = LocationManager.shared

    @Environment(\.presentationMode) var presentationMode
    @State private var showingDisclaimer = false

    public init(
        distanceEstimator: DistanceEstimator,
        thresholdManager: SafetyThresholdManager
    ) {
        self.distanceEstimator = distanceEstimator
        self.thresholdManager = thresholdManager
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 10/255, green: 12/255, blue: 16/255)
                    .ignoresSafeArea()

                Form {
                    // SECTION 1: CAMERA MOUNT
                    Section(header: Text("CAMERA POSITION").foregroundColor(.gray)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Camera mount height")
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%.2f m", distanceEstimator.cameraHeightMeters))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(Color(red: 46/255, green: 204/255, blue: 113/255))
                            }

                            Slider(
                                value: $distanceEstimator.cameraHeightMeters,
                                in: 1.00...2.00,
                                step: 0.05
                            )
                            .accentColor(Color(red: 46/255, green: 204/255, blue: 113/255))

                            Text("Sedan / hatchback ~1.25m; Crossover / SUV ~1.40m")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(red: 20/255, green: 24/255, blue: 33/255))

                    // SECTION 2: SAFETY THRESHOLD BUFFER
                    Section(header: Text("EARLY WARNING BUFFER").foregroundColor(.gray)) {
                        Picker("Extra buffer", selection: $thresholdManager.thresholdBufferMeters) {
                            Text("+0 m (Standard)").tag(Float(0.0))
                            Text("+5 m (Recommended)").tag(Float(5.0))
                            Text("+10 m (High Safety)").tag(Float(10.0))
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(red: 20/255, green: 24/255, blue: 33/255))

                    // SECTION 3: AUDIO ALERTS
                    Section(header: Text("ALERT AUDIO").foregroundColor(.gray)) {
                        Toggle("Mute alert chimes", isOn: $soundManager.isMuted)
                            .foregroundColor(.white)

                        Toggle("English Voice Alerts", isOn: $voiceManager.isVoiceEnabled)
                            .foregroundColor(.white)

                        if !soundManager.isMuted {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Volume")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(soundManager.volumePercent)%")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(soundManager.volumePercent) },
                                        set: { soundManager.volumePercent = Int($0) }
                                    ),
                                    in: 10...100,
                                    step: 5
                                )
                                .accentColor(Color(red: 46/255, green: 204/255, blue: 113/255))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowBackground(Color(red: 20/255, green: 24/255, blue: 33/255))

                    // SECTION 4: DEMO / SIMULATION MODE
                    Section(header: Text("SIMULATION / TEST").foregroundColor(.gray)) {
                        Toggle("Enable Demo Driving Mode", isOn: Binding(
                            get: { locationManager.isDemoMode },
                            set: { locationManager.setDemoMode(enabled: $0) }
                        ))
                        .foregroundColor(.white)

                        if locationManager.isDemoMode {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Simulated speed")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(locationManager.simulatedSpeedKmh)) km/h")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(Color(red: 245/255, green: 197/255, blue: 24/255))
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(locationManager.simulatedSpeedKmh) },
                                        set: { locationManager.setSimulatedSpeed(Float($0)) }
                                    ),
                                    in: 20...120,
                                    step: 5
                                )
                                .accentColor(Color(red: 245/255, green: 197/255, blue: 24/255))

                                Text("Allows testing all alert states indoors.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowBackground(Color(red: 20/255, green: 24/255, blue: 33/255))

                    // SECTION 5: INFO & LEGAL
                    Section(header: Text("ABOUT").foregroundColor(.gray)) {
                        Button(action: { showingDisclaimer = true }) {
                            HStack {
                                Text("Legal Disclaimer")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }

                        HStack {
                            Text("Distance Standard")
                                .foregroundColor(.white)
                            Spacer()
                            Text("Circular 38/2024")
                                .foregroundColor(.gray)
                        }

                        HStack {
                            Text("Data Privacy")
                                .foregroundColor(.white)
                            Spacer()
                            Text("100% On-Device Offline")
                                .foregroundColor(Color(red: 46/255, green: 204/255, blue: 113/255))
                        }

                        HStack {
                            Text("Version")
                                .foregroundColor(.white)
                            Spacer()
                            Text("1.0.0 (Build 1)")
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color(red: 20/255, green: 24/255, blue: 33/255))
                }
                .onAppear {
                    UITableView.appearance().backgroundColor = .clear
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(red: 46/255, green: 204/255, blue: 113/255))
                }
            }
            .sheet(isPresented: $showingDisclaimer) {
                DisclaimerView()
            }
        }
    }
}
