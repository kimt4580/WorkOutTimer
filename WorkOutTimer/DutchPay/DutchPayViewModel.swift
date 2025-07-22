//
//  DutchPayViewModel.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 7/22/25.
//
import SwiftUI
import Combine

@MainActor
class DutchPayViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var people: [Person] = []
    @Published var totalAmount: String = ""
    @Published var numberOfPeople: String = "2"
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    // MARK: - Constants
    private struct Constants {
        static let maxPeople = 10
        static let minPeople = 1
        static let defaultNames = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
    }
    
    // MARK: - Computed Properties
    var canAddPerson: Bool {
        people.count < Constants.maxPeople
    }
    
    var totalAmountDouble: Double {
        Double(totalAmount) ?? 0
    }
    
    var numberOfPeopleInt: Int {
        max(Constants.minPeople, min(Constants.maxPeople, Int(numberOfPeople) ?? 2))
    }
    
    var dutchPayResult: DutchPayResult? {
        guard totalAmountDouble > 0, !people.isEmpty else { return nil }
        
        let totalAdditionalAmount = people.reduce(0) { $0 + $1.additionalAmount }
        let remainingAmount = totalAmountDouble - totalAdditionalAmount
        let baseAmountPerPerson = remainingAmount / Double(people.count)
        
        guard baseAmountPerPerson >= 0 else { return nil }
        
        let payments = people.map { person in
            PersonPayment(
                person: person,
                totalPayment: baseAmountPerPerson + person.additionalAmount,
                basePayment: baseAmountPerPerson,
                additionalPayment: person.additionalAmount
            )
        }
        
        return DutchPayResult(
            totalAmount: totalAmountDouble,
            baseAmountPerPerson: baseAmountPerPerson,
            people: payments
        )
    }
    
    var isCalculationValid: Bool {
        guard let result = dutchPayResult else { return false }
        return result.baseAmountPerPerson >= 0
    }
    
    // MARK: - Initialization
    init() {
        setupInitialPeople()
    }
    
    // MARK: - Public Methods
    func addPerson() {
        guard canAddPerson else {
            showAlert(message: "최대 \(Constants.maxPeople)명까지만 추가할 수 있습니다.")
            return
        }
        
        let newName = getNextDefaultName()
        let newPerson = Person(name: newName)
        people.append(newPerson)
    }
    
    func removePerson(at index: Int) {
        guard people.indices.contains(index) else { return }
        guard people.count > 1 else {
            showAlert(message: "최소 1명은 있어야 합니다.")
            return
        }
        
        people.remove(at: index)
    }
    
    func updatePersonName(at index: Int, name: String) {
        guard people.indices.contains(index) else { return }
        people[index].name = name.isEmpty ? getDefaultName(for: index) : name
    }
    
    func updatePersonAdditionalAmount(at index: Int, amount: String) {
        guard people.indices.contains(index) else { return }
        people[index].additionalAmount = Double(amount) ?? 0
    }
    
    func updateNumberOfPeople(_ count: String) {
        numberOfPeople = count
    }
    
    func applyNumberOfPeople() {
        let targetCount = numberOfPeopleInt
        
        // 현재 인원수와 목표 인원수 비교하여 조정
        if people.count < targetCount {
            // 인원 추가
            while people.count < targetCount && people.count < Constants.maxPeople {
                addPerson()
            }
        } else if people.count > targetCount {
            // 인원 감소
            while people.count > targetCount && people.count > Constants.minPeople {
                people.removeLast()
            }
        }
    }
    
    func resetCalculation() {
        totalAmount = ""
        for index in people.indices {
            people[index].additionalAmount = 0
        }
    }
    
    // MARK: - Private Methods
    private func setupInitialPeople() {
        let initialCount = numberOfPeopleInt
        for i in 0..<initialCount {
            let person = Person(name: getDefaultName(for: i))
            people.append(person)
        }
    }
    
    private func getDefaultName(for index: Int) -> String {
        guard index < Constants.defaultNames.count else {
            return "Person\(index + 1)"
        }
        return Constants.defaultNames[index]
    }
    
    private func getNextDefaultName() -> String {
        return getDefaultName(for: people.count)
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }
}
