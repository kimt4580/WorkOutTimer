//
//  RandomPickerViewModel.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 7/22/25.
//


import SwiftUI
import Combine
import AudioToolbox

class RandomPickerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var participants: [String] = []
    @Published var currentDisplayName: String = ""
    @Published var pickerState: PickerState = .idle
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var spinSpeed: Double = 0.1 // 애니메이션 간격 (초)
    
    // MARK: - Private Properties
    private var animationTimer: Timer?
    private var currentIndex = 0
    
    // MARK: - Constants
    private struct Constants {
        static let maxParticipants = 10
        static let minParticipants = 2
        static let defaultParticipants = ["", "", "", ""]
        static let initialSpinSpeed = 0.15
        static let finalSpinSpeed = 0.8
        static let spinDuration = 3.0 // 총 애니메이션 시간
        static let vibrationCount = 3 // 진동 횟수
    }
    
    // MARK: - Computed Properties
    var canAddParticipant: Bool {
        participants.count < Constants.maxParticipants
    }
    
    var canStartPick: Bool {
        participants.count >= Constants.minParticipants &&
        !participants.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) &&
        pickerState != .spinning
    }
    
    var isSpinning: Bool {
        if case .spinning = pickerState {
            return true
        }
        return false
    }
    
    var winnerName: String? {
        if case .completed(let winner) = pickerState {
            return winner
        }
        return nil
    }
    
    // MARK: - Initialization
    init() {
        setupDefaultData()
    }
    
    deinit {
        stopAnimation()
    }
    
    // MARK: - Public Methods
    
    func addParticipant() {
        guard canAddParticipant else {
            showAlert(message: "최대 \(Constants.maxParticipants)명까지만 추가할 수 있습니다.")
            return
        }
        
        let newName = getNextDefaultName()
        participants.append(newName)
        
        if currentDisplayName.isEmpty {
            currentDisplayName = participants.first ?? ""
        }
    }
    
    func removeParticipant(at index: Int) {
        guard participants.indices.contains(index) else { return }
        guard participants.count > Constants.minParticipants else {
            showAlert(message: "최소 \(Constants.minParticipants)명은 있어야 합니다.")
            return
        }
        
        let removedName = participants[index]
        participants.remove(at: index)
        
        // 현재 표시중인 이름이 삭제된 경우 업데이트
        if currentDisplayName == removedName {
            currentDisplayName = participants.first ?? ""
        }
    }
    
    func updateParticipant(at index: Int, name: String) {
        guard participants.indices.contains(index) else { return }
        let oldName = participants[index]
        let newName = name.isEmpty ? getDefaultName(for: index) : name
        participants[index] = newName
        
        // 현재 표시중인 이름이 변경된 경우 업데이트
        if currentDisplayName == oldName {
            currentDisplayName = newName
        }
    }
    
    func startRandomPick() {
        guard canStartPick else {
            showAlert(message: "참가자를 2명 이상 입력해주세요.")
            return
        }
        
        pickerState = .spinning
        spinSpeed = Constants.initialSpinSpeed
        currentIndex = 0
        
        startSpinAnimation()
        
        // 점진적으로 속도 느려지게 하고 3초 후 종료
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.spinDuration) {
            self.finishPick()
        }
    }
    
    func resetPicker() {
        stopAnimation()
        pickerState = .idle
        currentDisplayName = participants.first ?? ""
    }
    
    func resetAll() {
        stopAnimation()
        setupDefaultData()
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultData() {
        participants = Array(Constants.defaultParticipants.prefix(4))
        currentDisplayName = participants.first ?? ""
        pickerState = .idle
    }
    
    private func getDefaultName(for index: Int) -> String {
        guard index < Constants.defaultParticipants.count else {
            return "참가자\(index + 1)"
        }
        return Constants.defaultParticipants[index]
    }
    
    private func getNextDefaultName() -> String {
        return getDefaultName(for: participants.count)
    }
    
    private func startSpinAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: spinSpeed, repeats: true) { [weak self] _ in
            self?.updateDisplayName()
        }
        
        // 1초마다 속도를 점진적으로 느리게
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
            guard let self = self, self.isSpinning else {
                timer.invalidate()
                return
            }
            
            // 속도를 점진적으로 느리게 (최대 0.8초까지)
            self.spinSpeed = min(self.spinSpeed * 1.15, Constants.finalSpinSpeed)
            
            // 기존 타이머 정지하고 새로운 속도로 재시작
            self.animationTimer?.invalidate()
            self.animationTimer = Timer.scheduledTimer(withTimeInterval: self.spinSpeed, repeats: true) { _ in
                self.updateDisplayName()
            }
        }
    }
    
    private func updateDisplayName() {
        guard !participants.isEmpty else { return }
        
        currentIndex = (currentIndex + 1) % participants.count
        currentDisplayName = participants[currentIndex]
    }
    
    private func finishPick() {
        stopAnimation()
        
        // 최종 당첨자 랜덤 선택
        let winner = participants.randomElement() ?? ""
        currentDisplayName = winner
        pickerState = .completed(winner: winner)
        
        // 진동 효과
        playVibrationSequence()
    }
    
    private func playVibrationSequence() {
        for i in 0..<Constants.vibrationCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }
}
