//
//  LadderGameModel.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 7/22/25.
//

import Foundation

// MARK: - Random Picker Models
enum PickerState: Equatable {
    case idle
    case spinning
    case completed(winner: String)
}

struct PickerResult {
    let winner: String
    let participants: [String]
    let timestamp: Date
}
