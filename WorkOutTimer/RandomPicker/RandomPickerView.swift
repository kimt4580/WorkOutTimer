//
//  LadderGameView.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 7/22/25.
//

import SwiftUI

struct RandomPickerView: View {
    @StateObject private var viewModel = RandomPickerViewModel()
    @FocusState private var focusedField: PickerFocusedField?
    @Environment(\.colorScheme) var colorScheme
    
    enum PickerFocusedField: Hashable {
        case participant(Int)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                if viewModel.isSpinning || viewModel.winnerName != nil {
                    pickerDisplaySection
                } else {
                    setupSection
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("랜덤 뽑기")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.pickerState != .idle {
                        Button("새 게임") {
                            viewModel.resetPicker()
                        }
                        .foregroundColor(.blue)
                    } else {
                        Button("초기화") {
                            viewModel.resetAll()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .alert("알림", isPresented: $viewModel.showingAlert) {
                Button("확인") { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .onTapGesture {
                hideKeyboard()
            }
            .gesture(
                DragGesture()
                    .onChanged { _ in
                        hideKeyboard()
                    }
            )
        }
    }
    
    // MARK: - Setup Section
    
    private var setupSection: some View {
        VStack(spacing: 24) {
            participantsSection
            startButton
        }
    }
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("참여자 목록")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("(\(viewModel.participants.count)/10명)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 자동 이름 채우기 버튼 추가
                if !viewModel.participants.isEmpty && viewModel.participants.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.hasPrefix("참여자") }) {
                    Button("자동으로 이름 채우기") {
                        viewModel.fillAutoNames()
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Array(viewModel.participants.enumerated()), id: \.offset) { index, participant in
                    participantCard(index: index, participant: participant)
                }
                
                if viewModel.canAddParticipant {
                    addParticipantCard
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    Color(colorScheme == .dark ? .systemGray6 : .systemBlue)
                        .opacity(colorScheme == .dark ? 1 : 0.1)
                )
        )
        .cornerRadius(16)
    }
    
    private func participantCard(index: Int, participant: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                TextField("참여자\(index + 1)", text: Binding(
                    get: { participant },
                    set: { viewModel.updateParticipant(at: index, name: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .participant(index))
                .font(.subheadline)
                
                if viewModel.participants.count > 2 {
                    Button(action: { viewModel.removeParticipant(at: index) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(colorScheme == .dark ? .systemGray5 : .white))
                .shadow(
                    color: colorScheme == .dark
                        ? .black.opacity(0.05)  // 다크모드: 희미한 흰색 그림자
                        : .black.opacity(0.1),  // 라이트모드: 희미한 검은색 그림자
                    radius: 2,
                    x: 0,
                    y: 1
                )
        )
    }
    
    private var addParticipantCard: some View {
        Button(action: viewModel.addParticipant) {
            VStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("참여자 추가")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5]))
            )
        }
    }
    
    private var startButton: some View {
        Button {
            viewModel.startRandomPick()
            hideKeyboard()
        } label: {
            Text("🎲 랜덤 뽑기 시작!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(height: 60)
                .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.blue, .purple]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        .disabled(!viewModel.canStartPick)
        .opacity(viewModel.canStartPick ? 1.0 : 0.6)
    }
    
    // MARK: - Picker Display Section
    
    private var pickerDisplaySection: some View {
        VStack(spacing: 40) {
            // 상태 표시
            statusSection
            
            // 메인 디스플레이
            nameDisplaySection
            
            // 액션 버튼
            if let winner = viewModel.winnerName {
                completionSection(winner: winner)
            }
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 8) {
            if viewModel.isSpinning {
                Text("🎯 뽑는 중...")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.orange)
            } else if viewModel.winnerName != nil {
                Text("🎉 당첨!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .scaleEffect(viewModel.winnerName != nil ? 1.2 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.winnerName)
            }
        }
    }
    
    private var nameDisplaySection: some View {
        VStack {
            Text(viewModel.currentDisplayName)
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .frame(width: 280, height: 280)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: animationColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                )
                .scaleEffect(animationScale)
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentDisplayName)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animationScale)
            
            if !viewModel.isSpinning && viewModel.winnerName == nil {
                Text("준비 완료!")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
            }
        }
    }
    
    private var animationColors: [Color] {
        if viewModel.isSpinning {
            return [.orange, .yellow]
        } else if viewModel.winnerName != nil {
            return [.red, .pink]
        } else {
            return [.blue, .cyan]
        }
    }
    
    private var animationScale: CGFloat {
        if viewModel.winnerName != nil {
            return 1.1
        } else if viewModel.isSpinning {
            return 0.95
        } else {
            return 1.0
        }
    }
    
    private func completionSection(winner: String) -> some View {
        VStack(spacing: 20) {
            Text("축하합니다! 🎊")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Button("다시 뽑기") {
                    viewModel.resetPicker()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("결과 공유") {
                    shareResult(winner: winner)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func hideKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func shareResult(winner: String) {
        let participants = viewModel.participants.joined(separator: ", ")
        let shareText = "🎲 랜덤 뽑기 결과\n\n참가자: \(participants)\n\n🎉 당첨자: \(winner)\n\n축하합니다! 🎊"
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

#Preview {
    RandomPickerView()
}
