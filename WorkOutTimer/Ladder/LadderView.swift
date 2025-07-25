//
//  LadderView.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 7/23/25.
//

import SwiftUI

// MARK: - Models
struct PathSegment: Identifiable {
    let id = UUID()
    let startPoint: CGPoint
    let endPoint: CGPoint
    let isHorizontal: Bool
    var isVisible: Bool = false
    var delay: Double = 0
    let participantIndex: Int
}

struct AnimatedLadderView: View {
    @State private var participants: [String] = [] // 빈 배열로 초기화
    @State private var winnerCount: Int = 1
    @State private var results: [String] = []
    @State private var ladderPaths: [[Bool]] = [] // 동적으로 생성
    
    @State private var pathSegments: [PathSegment] = []
    @State private var currentParticipant: Int = -1 // -1로 초기화 (아무도 선택되지 않음)
    @State private var isAnimating: Bool = false
    @State private var showResults: Bool = false
    @State private var finalResults: [String: String] = [:] // 참여자 -> 결과 매핑
    @State private var showSetup: Bool = true
    @State private var selectedParticipant: Int? = nil // 선택된 참가자
    @State private var showWinnerAlert: Bool = false // 당첨자 Alert 표시
    @State private var showLoserMessage: Bool = false // 꽝 메시지 표시
    @State private var showWinnerSheet: Bool = false // Sheet 표시 여부
    @State private var isLoser: Bool = false // 꽝인지 당첨인지 판단
    @State private var currentWinners: [String] = [] // 현재까지 찾은 당첨자들
    @State private var allWinnersFound: Bool = false // 모든 당첨자를 찾았는지
    @State var currentDisplayName: String = ""
    
    @FocusState private var focusedField: PickerFocusedField?
    
    enum PickerFocusedField: Hashable {
        case participant(Int)
    }
    
    // 애니메이션 설정
    private let segmentAnimationDuration: Double = 0.4
    private let participantDelay: Double = 0.5
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    if showSetup {
                        setupView
                    } else {
                        gameView
                            .padding(.top)
                    }
                }
                .padding()
                
                if showWinnerSheet {
                    ZStack {
                        Color.black.opacity(0.7)
                            .ignoresSafeArea(.all)
                            .onTapGesture {
                                showWinnerSheet = false
                                if allWinnersFound {
                                    resetToSetup()
                                }
                            }
                        
                        winnerAlertView
                            .allowsHitTesting(true) // 터치 이벤트 허용
                    }
                }
            }
            .navigationTitle("사다리타기 설정")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing:
                                    Button("초기화") {
                resetToInitialState()
            }
                .foregroundColor(isAnimating ? .gray : .red)
                .disabled(isAnimating)
            )
        }
    }
    
    // MARK: - Setup View
    
    private var setupView: some View {
        VStack(spacing: 20) {
            // 참가자 입력
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("참여자 목록")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("(\(participants.count)/8명)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !participants.isEmpty && participants.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.hasPrefix("참여자") }) {
                        Button("자동으로 이름 채우기") {
                            fillAutoNames()
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                
                if participants.isEmpty {
                    VStack(spacing: 8) {
                        Text("참여자를 추가해주세요")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        
                        Button("참여자 추가") {
                            addParticipant()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(Array(participants.enumerated()), id: \.offset) { index, name in
                        HStack {
                            TextField("참여자\(index + 1)", text: Binding(
                                get: { participants[index] },
                                set: { participants[index] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .participant(index))
                            .font(.subheadline)
                            
                            if participants.count > 0 {
                                Button(action: { removeParticipant(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    if participants.count < 8 {
                        Button("참가자 추가") {
                            addParticipant()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // 당첨자 수 선택
            if !participants.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("당첨자 수")
                        .font(.headline)
                    
                    HStack {
                        Stepper("\(winnerCount)명", value: $winnerCount, in: 1...max(1, participants.count))
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                
                Button("게임 시작") {
                    startGame()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(participants.count < 2 ||
                          participants.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ||
                          winnerCount >= participants.count)
            }
            
            if showSetup {
                Spacer()
            }
        }
    }
    
    // MARK: - Game View
    
    private var gameView: some View {
        ZStack {
            // 메인 게임 화면
            ScrollView {
                VStack(spacing: 20) {
                    // 참가자 이름들
                    participantNamesView
                    
                    // 사다리 + 애니메이션
                    GeometryReader { geometry in
                        let size = geometry.size
                        ZStack {
                            // 1️⃣ 기본 회색 사다리
                            staticLadderView(size: size)
                            
                            // 2️⃣ 애니메이션되는 색칠된 세그먼트들
                            ForEach(pathSegments) { segment in
                                AnimatedSegmentView(
                                    segment: segment,
                                    color: participantColor(index: segment.participantIndex)
                                )
                            }
                        }
                    }
                    .frame(height: 400)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // 결과들
                    resultNamesView
                    
                    // 컨트롤 버튼
                    controlButtons
                }
                .padding()
            }
            .allowsHitTesting(!showWinnerSheet) // winnerSheet가 떠있으면 하위 뷰 터치 비활성화
            
            // 당첨자 Alert (ZStack 방식) - ScrollView 밖에 위치
        }
    }
    
    // MARK: - 당첨자 결과 뷰 (ZStack Overlay)
    private var winnerAlertView: some View {
        ZStack {
            // 메인 컨텐츠 - SafeArea 고려
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 30) {
                        if !isLoser && allWinnersFound {
                            // 모든 당첨자가 나온 후 최종 당첨 화면
                            VStack(spacing: 20) {
                                Text("🎉")
                                    .font(.system(size: 80))
                                    .scaleEffect(1.2)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showWinnerSheet)
                                
                                Text("당첨!")
                                    .font(.largeTitle)
                                    .fontWeight(.black)
                                    .foregroundColor(.red)
                                
                                VStack(spacing: 15) {
                                    Text("당첨자")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    ForEach(currentWinners.indices, id: \.self) { index in
                                        HStack {
                                            Text("\(index + 1)등")
                                                .font(.title3)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                            
                                            Text(currentWinners[index])
                                                .font(.title)
                                                .fontWeight(.bold)
                                                .foregroundColor(getWinnerColor(winner: currentWinners[index]))
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(getWinnerColor(winner: currentWinners[index]).opacity(0.1))
                                        )
                                    }
                                }
                                
                                Text("축하합니다! 🎊")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                        } else if !isLoser {
                            // 개별 당첨자 화면
                            VStack(spacing: 20) {
                                Text("🎉")
                                    .font(.system(size: 80))
                                    .scaleEffect(1.2)
                                
                                Text("당첨!")
                                    .font(.largeTitle)
                                    .fontWeight(.black)
                                    .foregroundColor(.red)
                                
                                if let winner = finalResults.first(where: { $0.value == "🎉 당첨!" })?.key {
                                    Text(winner)
                                        .font(.system(size: 48, weight: .black, design: .rounded))
                                        .foregroundColor(getWinnerColor(winner: winner))
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(getWinnerColor(winner: winner).opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(getWinnerColor(winner: winner), lineWidth: 4)
                                                )
                                        )
                                        .scaleEffect(1.1)
                                }
                                
                                Text("축하합니다! 🎊")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // 확인 버튼
                        Button("확인") {
                            showWinnerSheet = false
                        }
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    Spacer()
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 20)
                )
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: showWinnerSheet)
    }
    
    private var participantNamesView: some View {
        HStack(spacing: 0) {
            ForEach(Array(participants.enumerated()), id: \.offset) { index, name in
                Button(action: {
                    if !isAnimating {
                        startIndividualAnimation(participantIndex: index)
                    }
                }) {
                    Text(name)
                        .font(.system(size: participants.count == 8 ? 11 : participants.count == 7 ? 12 : participants.count == 6 ? 14 : 17))
                        .fontWeight(.bold)
                        .foregroundColor(participantColor(index: index)) // 항상 원래 색상 유지
                        .opacity(getParticipantOpacity(index: index))
                        .frame(maxWidth: .infinity)
                        .scaleEffect(currentParticipant == index && isAnimating ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentParticipant)
                        .animation(.easeInOut(duration: 0.3), value: isAnimating)
                }
                .buttonStyle(.plain)
                .disabled(isAnimating)
            }
        }
        .padding(.top, 20) // 다이나믹 아일랜드 공간 확보
    }
    
    private var resultNamesView: some View {
        HStack(spacing: 0) {
            ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                Text(result)
                    .font(.system(size: participants.count == 8 ? 11 : participants.count == 7 ? 12 : participants.count == 6 ? 14 : 17))
                    .fontWeight(.semibold)
                    .foregroundColor(getResultColor(index: index))
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func getWinnerColor(winner: String) -> Color {
        if let index = participants.firstIndex(of: winner) {
            return participantColor(index: index)
        }
        return .red
    }
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            if !isAnimating && !showResults && selectedParticipant == nil {
                Text("참가자 이름을 눌러서 사다리를 타보세요!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if showResults && !showWinnerAlert && !showLoserMessage {
                Button("다시 하기") {
                    resetAnimation()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("새 게임") {
                    resetToSetup()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
    
    // MARK: - Static Ladder
    
    private func staticLadderView(size: CGSize) -> some View {
        Canvas { context, _ in
            drawStaticLadder(context: context, size: size)
        }
    }
    
    private func drawStaticLadder(context: GraphicsContext, size: CGSize) {
        let columnWidth = size.width / CGFloat(participants.count)
        let rowHeight = size.height / CGFloat(ladderPaths.count + 1)
        
        // 세로선 그리기
        for col in 0..<participants.count {
            let x = CGFloat(col) * columnWidth + columnWidth / 2
            let startPoint = CGPoint(x: x, y: 0)
            let endPoint = CGPoint(x: x, y: size.height)
            
            var path = Path()
            path.move(to: startPoint)
            path.addLine(to: endPoint)
            
            context.stroke(path, with: .color(.primary.opacity(0.3)), lineWidth: 2)
        }
        
        // 가로선 그리기
        for (rowIndex, row) in ladderPaths.enumerated() {
            let y = CGFloat(rowIndex + 1) * rowHeight
            
            for (colIndex, hasHorizontal) in row.enumerated() {
                if hasHorizontal {
                    let startX = CGFloat(colIndex) * columnWidth + columnWidth / 2
                    let endX = CGFloat(colIndex + 1) * columnWidth + columnWidth / 2
                    
                    let startPoint = CGPoint(x: startX, y: y)
                    let endPoint = CGPoint(x: endX, y: y)
                    
                    var path = Path()
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                    
                    context.stroke(path, with: .color(.primary.opacity(0.3)), lineWidth: 2)
                }
            }
        }
    }
    
    // MARK: - Animation Setup
    
    private func generateLadder() {
        ladderPaths = []
        let ladderHeight = 5 // 사다리 높이
        
        for _ in 0..<ladderHeight {
            var rowPaths: [Bool] = []
            var lastHadBridge = false
            
            for _ in 0..<(participants.count - 1) {
                // 연속된 가로선 방지
                if lastHadBridge {
                    rowPaths.append(false)
                    lastHadBridge = false
                } else {
                    // 30% 확률로 가로선 생성
                    let hasBridge = Double.random(in: 0...1) < 0.3
                    rowPaths.append(hasBridge)
                    lastHadBridge = hasBridge
                }
            }
            
            ladderPaths.append(rowPaths)
        }
    }
    
    private func generateResults() {
        results = []
        // 당첨자 수만큼 "🎉 당첨!" 추가
        for i in 0..<participants.count {
            if i < winnerCount {
                results.append("🎉 당첨!")
            } else {
                results.append("🙁 꽝")
            }
        }
        results.shuffle() // 결과를 랜덤하게 섞음
    }
    
    private func addParticipant() {
        participants.append("")
    }
    
    private func removeParticipant(at index: Int) {
        participants.remove(at: index)
        if participants.isEmpty {
            winnerCount = 1
        } else {
            winnerCount = min(winnerCount, participants.count)
        }
    }
    
    private func startGame() {
        // 빈 이름 제거
        participants = participants.compactMap { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        
        generateLadder() // 새로운 사다리 생성
        generateResults()
        showSetup = false
        print("🎯 당첨자 수: \(winnerCount), 총 인원: \(participants.count)")
        print("🎲 생성된 결과: \(results)")
        print("🪜 새로 생성된 사다리 구조:")
        for (rowIndex, row) in ladderPaths.enumerated() {
            print("  행 \(rowIndex): \(row)")
        }
    }
    
    private func startIndividualAnimation(participantIndex: Int) {
        // 이전 선들 모두 제거
        pathSegments.removeAll()
        
        isAnimating = true
        currentParticipant = participantIndex
        selectedParticipant = participantIndex
        showResults = false
        
        // 선택된 참가자의 경로만 애니메이션
        animateParticipantPath(participantIndex: participantIndex)
        
        // 애니메이션 완료 후 결과 표시
        let animationTime = calculateParticipantAnimationTime()
        DispatchQueue.main.asyncAfter(deadline: .now() + animationTime + 0.5) {
            calculateIndividualResult(participantIndex: participantIndex)
            showResults = true
            isAnimating = false
        }
    }
    
    private func calculateIndividualResult(participantIndex: Int) {
        let participant = participants[participantIndex]
        let finalColumn = calculateFinalColumn(participantIndex: participantIndex)
        let result = results[finalColumn]
        finalResults[participant] = result
        
        print("🔍 \(participant) → 열 \(finalColumn) → \(result)")
        
        // 🎉 당첨자가 나온 경우
        if result == "🎉 당첨!" {
            currentWinners.append(participant)
            
            // 모든 당첨자를 찾았는지 확인
            if currentWinners.count >= winnerCount {
                allWinnersFound = true
                isLoser = false
                showWinnerResult(winners: currentWinners)
            } else {
                isLoser = false
            }
            
            // 진동 효과
            playVibrationSequence()
            
            // Alert 표시
            showWinnerSheet = true
        } else {
            // 꽝인 경우
            isLoser = true
            showLoserMessage = true
        }
    }
    
    private func playVibrationSequence() {
        // 3번 진동
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    private func showWinnerResult(winners: [String]) {
        // 나머지 모든 참가자를 꽝으로 처리 (전체 결과가 필요한 경우)
        for participant in participants {
            if !winners.contains(participant) {
                finalResults[participant] = "🙁 꽝"
            }
        }
        
        print("🏆 모든 당첨자 발견! \(winners)")
        print("📋 최종 결과: \(finalResults)")
    }
    
    private func startAnimation() {
        // 기존 전체 애니메이션 (사용하지 않음)
        isAnimating = true
        currentParticipant = 0
        showResults = false
        finalResults.removeAll()
        
        // 모든 세그먼트 초기화
        pathSegments.removeAll()
        
        animateNextParticipant()
    }
    
    private func animateNextParticipant() {
        guard currentParticipant < participants.count else {
            // 모든 참가자 애니메이션 완료
            calculateFinalResults()
            showResults = true
            isAnimating = false
            return
        }
        
        // 현재 참가자의 경로 계산 및 애니메이션
        animateParticipantPath(participantIndex: currentParticipant)
        
        // 다음 참가자로 넘어가기
        let totalAnimationTime = calculateParticipantAnimationTime()
        DispatchQueue.main.asyncAfter(deadline: .now() + totalAnimationTime + participantDelay) {
            currentParticipant += 1
            animateNextParticipant()
        }
    }
    
    private func animateParticipantPath(participantIndex: Int) {
        // GeometryReader에서 실제 크기를 가져와야 하는데, 일단 고정값 대신 계산된 크기 사용
        // 여기서는 400x400 고정 크기로 계산하되, 실제 렌더링 시에는 GeometryReader 크기에 맞춰 조정
        let path = calculateParticipantPath(participantIndex: participantIndex)
        let segments = createSegmentsFromPath(path: path, participantIndex: participantIndex)
        
        // 세그먼트들을 순차적으로 애니메이션
        for (index, segment) in segments.enumerated() {
            var animatedSegment = segment
            animatedSegment.delay = Double(index) * segmentAnimationDuration
            pathSegments.append(animatedSegment)
            
            // 애니메이션 시작
            DispatchQueue.main.asyncAfter(deadline: .now() + animatedSegment.delay) {
                withAnimation(.easeInOut(duration: segmentAnimationDuration)) {
                    if let segmentIndex = pathSegments.firstIndex(where: { $0.id == animatedSegment.id }) {
                        pathSegments[segmentIndex].isVisible = true
                    }
                }
            }
        }
    }
    
    func fillAutoNames() {
        for index in participants.indices {
            participants[index] = getAutoGeneratedName(for: index)
        }
        
        // 현재 표시 이름도 업데이트
        if currentDisplayName.isEmpty || currentDisplayName == "" {
            currentDisplayName = participants.first ?? ""
        }
    }
    
    private func getAutoGeneratedName(for index: Int) -> String {
        return "참여자\(index + 1)"
    }
    
    private func calculateParticipantAnimationTime() -> Double {
        let pathLength = calculateParticipantPath(participantIndex: currentParticipant).count - 1
        return Double(pathLength) * segmentAnimationDuration
    }
    
    private func calculateFinalResults() {
        for (index, participant) in participants.enumerated() {
            let finalColumn = calculateFinalColumn(participantIndex: index)
            let result = results[finalColumn]
            finalResults[participant] = result
        }
    }
    
    private func calculateFinalColumn(participantIndex: Int) -> Int {
        var currentColumn = participantIndex
        
        print("🚀 \(participants[participantIndex]) 시작: 열 \(currentColumn)")
        
        // 사다리 로직 적용
        for (rowIndex, row) in ladderPaths.enumerated() {
            print("  행 \(rowIndex): 현재 열 \(currentColumn)")
            
            // 왼쪽 가로선 확인 (현재 열의 왼쪽에 가로선이 있는지)
            if currentColumn > 0 && row[currentColumn - 1] {
                currentColumn -= 1
                print("    ← 왼쪽으로 이동: 열 \(currentColumn)")
            }
            // 오른쪽 가로선 확인 (현재 열에 가로선이 있는지)
            else if currentColumn < participants.count - 1 && row[currentColumn] {
                currentColumn += 1
                print("    → 오른쪽으로 이동: 열 \(currentColumn)")
            } else {
                print("    ↓ 직진")
            }
        }
        
        print("🏁 \(participants[participantIndex]) 최종: 열 \(currentColumn)")
        return currentColumn
    }
    
    // MARK: - Path Calculation
    
    private func calculateParticipantPath(participantIndex: Int) -> [CGPoint] {
        // 정규화된 좌표로 계산 (0.0 ~ 1.0)
        let normalizedColumnWidth = 1.0 / CGFloat(participants.count)
        let normalizedRowHeight = 1.0 / CGFloat(ladderPaths.count + 1)
        
        var path: [CGPoint] = []
        var currentColumn = participantIndex
        
        // 시작점 (정규화된 좌표)
        let startX = CGFloat(participantIndex) * normalizedColumnWidth + normalizedColumnWidth / 2
        path.append(CGPoint(x: startX, y: 0))
        
        // 각 행을 거쳐가며 경로 계산
        for (rowIndex, row) in ladderPaths.enumerated() {
            let y = CGFloat(rowIndex + 1) * normalizedRowHeight
            
            // 현재 위치에서 수직으로 내려오기
            let currentX = CGFloat(currentColumn) * normalizedColumnWidth + normalizedColumnWidth / 2
            path.append(CGPoint(x: currentX, y: y))
            
            // 가로선 확인 및 이동
            if currentColumn > 0 && row[currentColumn - 1] {
                currentColumn -= 1
                let newX = CGFloat(currentColumn) * normalizedColumnWidth + normalizedColumnWidth / 2
                path.append(CGPoint(x: newX, y: y))
            } else if currentColumn < participants.count - 1 && row[currentColumn] {
                currentColumn += 1
                let newX = CGFloat(currentColumn) * normalizedColumnWidth + normalizedColumnWidth / 2
                path.append(CGPoint(x: newX, y: y))
            }
        }
        
        // 최종 목적지
        let finalX = CGFloat(currentColumn) * normalizedColumnWidth + normalizedColumnWidth / 2
        path.append(CGPoint(x: finalX, y: 1.0))
        
        return path
    }
    
    private func createSegmentsFromPath(path: [CGPoint], participantIndex: Int) -> [PathSegment] {
        var segments: [PathSegment] = []
        
        for i in 1..<path.count {
            let start = path[i-1]
            let end = path[i]
            let isHorizontal = abs(start.x - end.x) > abs(start.y - end.y)
            
            let segment = PathSegment(
                startPoint: start,
                endPoint: end,
                isHorizontal: isHorizontal,
                participantIndex: participantIndex
            )
            segments.append(segment)
        }
        
        return segments
    }
    
    private func resetAnimation() {
        isAnimating = false
        showResults = false
        showWinnerAlert = false
        showLoserMessage = false
        showWinnerSheet = false
        currentParticipant = -1
        selectedParticipant = nil
        pathSegments.removeAll()
        finalResults.removeAll()
        currentWinners.removeAll()
        allWinnersFound = false
        isLoser = false
        generateLadder() // 새로운 사다리 생성
        generateResults() // 새로운 결과 생성
    }
    
    private func resetToSetup() {
        resetAnimation()
        showSetup = true
    }
    
    // MARK: - 초기화 함수
    private func resetToInitialState() {
        if isAnimating {
            isAnimating = false
            currentParticipant = -1
        }
        
        participants = []
        winnerCount = 1
        results = []
        ladderPaths = []
        pathSegments.removeAll()
        currentParticipant = -1
        isAnimating = false
        showResults = false
        finalResults.removeAll()
        showSetup = true
        selectedParticipant = nil
        showWinnerAlert = false
        showLoserMessage = false
        showWinnerSheet = false
        isLoser = false
        currentWinners.removeAll()
        allWinnersFound = false
    }
    
    // MARK: - Helper Methods
    
    private func participantColor(index: Int) -> Color {
        let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .brown, .cyan]
        return colors[index % colors.count]
    }
    
    private func getParticipantOpacity(index: Int) -> Double {
        if isAnimating {
            // 애니메이션 중일 때: 현재 사다리 타는 사람은 선명하게, 나머지는 흐리게
            if currentParticipant == index {
                return 1.0 // 사다리 타는 사람은 선명하게
            } else {
                return 0.3 // 다른 사람들만 흐리게
            }
        } else {
            // 애니메이션 아닐 때: 모두 선명하게
            return 1.0
        }
    }
    
    private func getParticipantColor(index: Int) -> Color {
        // 항상 고유 색상 유지
        return participantColor(index: index)
    }
    
    private func getResultColor(index: Int) -> Color {
        // 모든 완료된 결과들의 색상을 표시
        for (participant, result) in finalResults {
            if let participantIndex = participants.firstIndex(of: participant) {
                let finalColumn = calculateFinalColumn(participantIndex: participantIndex)
                if finalColumn == index {
                    return participantColor(index: participantIndex)
                }
            }
        }
        
        // 현재 진행 중인 참가자의 결과 색상
        if let selectedIndex = selectedParticipant,
           showResults && !isAnimating {
            let finalColumn = calculateFinalColumn(participantIndex: selectedIndex)
            if finalColumn == index {
                return participantColor(index: selectedIndex)
            }
        }
        
        return .secondary
    }
    
    private func getParticipantFinalColor(participant: String) -> Color {
        if let index = participants.firstIndex(of: participant) {
            return participantColor(index: index)
        }
        return .primary
    }
}

// MARK: - Animated Segment View
struct AnimatedSegmentView: View {
    let segment: PathSegment
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            
            // 정규화된 좌표를 실제 크기로 변환
            let startPoint = CGPoint(
                x: segment.startPoint.x * size.width,
                y: segment.startPoint.y * size.height
            )
            let endPoint = CGPoint(
                x: segment.endPoint.x * size.width,
                y: segment.endPoint.y * size.height
            )
            
            Path { path in
                path.move(to: startPoint)
                path.addLine(to: endPoint)
            }
            .trim(from: 0, to: segment.isVisible ? 1 : 0)
            .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .shadow(color: color.opacity(0.3), radius: 2)
            .animation(.easeInOut(duration: 0.3), value: segment.isVisible)
        }
    }
}

// MARK: - Preview
#Preview {
    AnimatedLadderView()
}
