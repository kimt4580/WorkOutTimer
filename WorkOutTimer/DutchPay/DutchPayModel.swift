//
//  DutchPayModels.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 7/22/25.
//

import Foundation

// MARK: - Person Model
struct Person: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var additionalAmount: Double = 0
    
    init(name: String) {
        self.name = name
    }
}

// MARK: - Dutch Pay Result
struct DutchPayResult {
    let totalAmount: Double
    let baseAmountPerPerson: Double
    let people: [PersonPayment]
}

struct PersonPayment {
    let person: Person
    let totalPayment: Double
    let basePayment: Double
    let additionalPayment: Double
}
