//
//  WorkTimeView.swift
//  WorkOutTimer
//
//
//  WorkTimeView.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 3/13/25.
//

import SwiftUI

struct WorkTimeView: View {
    @StateObject private var viewModel = WorkTimerViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !viewModel.isWorking {
                    workSetupSection
                } else {
                    workingSection
                }
                
                actionButton
            }
            .padding()
            .navigationTitle("퇴근 타이머")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.validateWorkDate()
                viewModel.checkNotificationPermission()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                viewModel.handleAppBecomeActive()
            }
            .alert("이전 근무 데이터", isPresented: $viewModel.showingDataCleanupAlert) {
                Button("확인") { }
            } message: {
                Text("이전 날짜의 근무 데이터가 정리되었습니다.")
            }
        }
    }
    
    // MARK: - UI Components
    
    private var workSetupSection: some View {
        VStack(spacing: 16) {
            workTimePickerSection
            halfDayToggleSection
            workPreviewSection
            
            if !viewModel.notificationPermissionGranted {
                notificationPermissionSection
            }
        }
    }
    
    private var workTimePickerSection: some View {
        VStack(spacing: 12) {
            Text("출근 시간")
                .font(.headline)
            DatePicker(
                "출근 시간",
                selection: $viewModel.selectedDate,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.compact)
            .environment(\.locale, Locale(identifier: "ko_KR"))
        }
    }
    
    private var halfDayToggleSection: some View {
        HStack {
            Text("반차 사용")
                .font(.headline)
            Spacer()
            Toggle("", isOn: $viewModel.isHalfDayOff)
                .labelsHidden()
        }
    }
    
    private var workPreviewSection: some View {
        VStack(spacing: 8) {
            Text("근무 설정")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("근무시간: \(viewModel.workHoursText)")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("퇴근시간: \(viewModel.previewEndTime)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            notificationStatusView
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var notificationStatusView: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.notificationPermissionGranted ? "bell.fill" : "bell.slash")
                .foregroundColor(viewModel.notificationPermissionGranted ? .green : .orange)
            Text(viewModel.notificationPermissionGranted ? "퇴근 알림 활성화" : "알림 권한 필요")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var notificationPermissionSection: some View {
        Button("🔔 알림 허용하기") {
            viewModel.requestNotificationPermission()
        }
        .buttonStyle(.bordered)
        .foregroundColor(.orange)
    }
    
    private var workingSection: some View {
        VStack(spacing: 20) {
            Text(viewModel.currentWorkInfo)
                .font(.caption)
                .foregroundColor(.secondary)
            
            timerCircleView
        }
    }
    
    private var timerCircleView: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(lineWidth: 15)
                .opacity(0.2)
                .foregroundColor(viewModel.isOvertime ? .orange : .red)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: min(1, 1 - viewModel.progress))
                .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round))
                .foregroundColor(viewModel.isOvertime ? .orange : .red)
                .rotationEffect(.degrees(-90))
            
            // Timer content
            timerContent
        }
        .frame(width: 250, height: 250)
        .accessibilityLabel("퇴근 타이머")
        .accessibilityValue(viewModel.isOvertime ? "연장근무 중" : "퇴근까지 남은 시간")
    }
    
    private var timerContent: some View {
        VStack(spacing: 4) {
            if viewModel.isOvertime {
                Text("연장근무")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text(Date(timeIntervalSince1970: viewModel.workEndTime), style: .timer)
                    .font(.system(size: 40, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(.orange)
            } else {
                Text("퇴근까지")
                    .font(.headline)
                Text(Date(timeIntervalSince1970: viewModel.workEndTime), style: .timer)
                    .font(.system(size: 40, weight: .bold))
                    .monospacedDigit()
            }
            Text("🏠 \(viewModel.formattedEndTime)")
                .font(.system(size: 20, weight: .semibold))
        }
    }
    
    private var actionButton: some View {
        Button(viewModel.isWorking ? "퇴근하기" : "😱 출근하기") {
            if viewModel.isWorking {
                viewModel.endWork()
            } else {
                viewModel.startWork()
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityHint(viewModel.isWorking ? "퇴근 처리를 합니다" : "출근 타이머를 시작합니다")
    }
}

#Preview {
    WorkTimeView()
}
