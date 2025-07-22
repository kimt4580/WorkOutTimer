//
//  DutchPayView.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 7/22/25.
//

import SwiftUI

struct DutchPayView: View {
    @StateObject private var viewModel = DutchPayViewModel()
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField: Hashable {
        case totalAmount
        case numberOfPeople
        case personName(Int)
        case personAdditional(Int)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    totalAmountSection
                    peopleCountSection
                    peopleListSection
                    
                    if viewModel.isCalculationValid {
                        resultSection
                    }
                    
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("더치페이")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("초기화") {
                        viewModel.resetCalculation()
                    }
                    .foregroundColor(.red)
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
    
    // MARK: - UI Components
    
    private var totalAmountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("총 금액")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                TextField("금액 입력", text: $viewModel.totalAmount)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .totalAmount)
                Text("원")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var peopleCountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("인원 수")
                    .font(.headline)
                Spacer()
                Text("(\(viewModel.people.count)/10명)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                TextField("인원 수", text: $viewModel.numberOfPeople)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .numberOfPeople)
                
                Text("명")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("확인") {
                    viewModel.applyNumberOfPeople()
                    focusedField = nil
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.numberOfPeopleInt == viewModel.people.count)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var peopleListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("참여자 목록")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(Array(viewModel.people.enumerated()), id: \.element.id) { index, person in
                personRow(index: index, person: person)
            }
            
            // 하단 중앙에 + 버튼
            if viewModel.canAddPerson {
                HStack {
                    Spacer()
                    Button(action: viewModel.addPerson) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("참여자 추가")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
    }
    
    private func personRow(index: Int, person: Person) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(index + 1).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .leading)
                
                TextField("이름", text: Binding(
                    get: { person.name },
                    set: { viewModel.updatePersonName(at: index, name: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .personName(index))
                
                Spacer()
                
                if viewModel.people.count > 1 {
                    Button(action: { viewModel.removePerson(at: index) }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            
            HStack {
                Text("추가 금액")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack {
                    TextField("0", text: Binding(
                        get: { person.additionalAmount == 0 ? "" : String(Int(person.additionalAmount)) },
                        set: { viewModel.updatePersonAdditionalAmount(at: index, amount: $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .personAdditional(index))
                    .frame(width: 100)
                    
                    Text("원")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("계산 결과")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let result = viewModel.dutchPayResult {
                VStack(spacing: 8) {
                    resultSummaryView(result: result)
                    
                    Divider()
                    
                    ForEach(Array(result.people.enumerated()), id: \.offset) { _, payment in
                        personPaymentRow(payment: payment)
                    }
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func resultSummaryView(result: DutchPayResult) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("총 금액")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(result.totalAmount))원")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text("1인당 기본 금액")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(result.baseAmountPerPerson))원")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private func personPaymentRow(payment: PersonPayment) -> some View {
        HStack {
            Text(payment.person.name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(payment.totalPayment))원")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if payment.additionalPayment > 0 {
                    Text("(기본 \(Int(payment.basePayment)) + 추가 \(Int(payment.additionalPayment)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            Button("계산하기") {
                focusedField = nil // 키보드 숨기기
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.totalAmountDouble <= 0 || viewModel.people.isEmpty)
            
            Button("공유하기") {
                shareResult()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!viewModel.isCalculationValid)
        }
    }
    
    // MARK: - Private Methods
    
    private func hideKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func shareResult() {
        guard let result = viewModel.dutchPayResult else { return }
        
        var shareText = "💰 더치페이 계산 결과\n\n"
        shareText += "총 금액: \(Int(result.totalAmount))원\n"
        shareText += "1인당 기본: \(Int(result.baseAmountPerPerson))원\n\n"
        
        for payment in result.people {
            shareText += "\(payment.person.name): \(Int(payment.totalPayment))원"
            if payment.additionalPayment > 0 {
                shareText += " (추가 \(Int(payment.additionalPayment))원)"
            }
            shareText += "\n"
        }
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

#Preview {
    DutchPayView()
}
