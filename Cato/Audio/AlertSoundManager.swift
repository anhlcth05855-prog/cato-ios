import Foundation
import AudioToolbox
import AVFoundation
import UIKit

/// Quản lý âm thanh cảnh báo ADAS chuẩn: êm ái, rõ ràng, không gây chói tai hay khó chịu
public class AlertSoundManager: ObservableObject {

    public static let shared = AlertSoundManager()

    @Published public var isMuted: Bool = false
    @Published public var volumePercent: Int = 70

    private var currentLevel: AlertLevel = .safe
    private var lastCautionToneTime: TimeInterval = 0
    private var dangerTimer: Timer?
    private var isPlayingDangerLoop: Bool = false

    private let feedbackGenerator = UINotificationFeedbackGenerator()

    public init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    /// Cập nhật mức độ cảnh báo hiện tại từ bộ đánh giá an toàn
    public func updateAlertState(level: AlertLevel) {
        if isMuted || volumePercent <= 0 {
            stopAlert()
            return
        }

        if level == currentLevel && level != .danger {
            return
        }
        currentLevel = level

        switch level {
        case .safe:
            stopAlert()

        case .caution:
            stopAlert()
            let now = CACurrentMediaTime()
            // Tiếng ping nhẹ báo hiệu khi tiến sát ngưỡng (giãn cách tối thiểu 5s để không làm phiền)
            if now - lastCautionToneTime > 5.0 {
                lastCautionToneTime = now
                playCautionTone()
            }

        case .danger:
            if !isPlayingDangerLoop {
                startDangerAlarmLoop()
            }
        }
    }

    /// Tiếng ping nhẹ trạng thái Thận trọng
    private func playCautionTone() {
        guard !isMuted else { return }
        // System Sound 1057 (Tink) hoặc 1052 (Input Key Click / Gentle Tone)
        AudioServicesPlaySystemSound(1057)
        feedbackGenerator.notificationOccurred(.warning)
    }

    /// Chuỗi tiếng bíp nguy hiểm: 3 tiếng bíp nhịp điệu ADAS (bíp-bíp-bíp),
    /// sau đó nghỉ 2.5 giây rồi mới lặp lại nếu xe phía trước vẫn quá gần.
    private func startDangerAlarmLoop() {
        stopAlert()
        isPlayingDangerLoop = true

        // Phát đợt đầu tiên ngay lập tức
        triggerDangerBurst()

        // Lặp lại chu kỳ 2.5 giây
        dangerTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: true) { [weak self] _ in
            guard let self = self, self.currentLevel == .danger, !self.isMuted else {
                self?.stopAlert()
                return
            }
            self.triggerDangerBurst()
        }
    }

    private func triggerDangerBurst() {
        guard !isMuted, currentLevel == .danger else { return }

        // Bíp 1
        AudioServicesPlaySystemSound(1052)
        feedbackGenerator.notificationOccurred(.error)

        // Bíp 2 sau 160ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            guard let self = self, self.currentLevel == .danger, !self.isMuted else { return }
            AudioServicesPlaySystemSound(1052)
        }

        // Bíp 3 sau 320ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            guard let self = self, self.currentLevel == .danger, !self.isMuted else { return }
            AudioServicesPlaySystemSound(1052)
        }
    }

    public func stopAlert() {
        isPlayingDangerLoop = false
        dangerTimer?.invalidate()
        dangerTimer = nil
    }

    deinit {
        stopAlert()
    }
}
