//
//  SuitcaseFeatures.swift
//  CaBot-Attend
//
//  Created by Daisuke Sato on 11/30/24.
//  Copyright © 2024 Carnegie Mellon University. All rights reserved.
//

import Foundation
import SwiftUI

final class SuitcaseFeatures: ObservableObject {
    enum HandleSide: String, CaseIterable {
        case left = "left"
        case right = "right"

        var imageName: String {
            switch self {
            case .left: return "AISuitcaseHandle.left"
            case .right: return "AISuitcaseHandle.right"
            }
        }
        var text: String{
            switch self{
            case .left: return "GRIP_HAND_LEFT"
            case .right: return "GRIP_HAND_RIGHT"
            }
        }
        var color: Color {
            switch self{
            case .left: return .blue
            case .right: return .orange
            }
        }
        static func possibleOptions(options: String?) -> [HandleSide] {
            if let options = options {
                var results: [HandleSide] = []
                for item in options.split(separator: ",") {
                    if let option = HandleSide(rawValue: String(item)) {
                        results.append(option)
                    }
                }
                return results
            }
            return [.left]
        }
    }

    enum TouchMode: String, CaseIterable {
        case cap = "cap"
        case tof = "tof"
        case dual = "dual"

        var imageName: String {
            switch self {
            case .cap: return "c.circle"
            case .tof: return "t.circle"
            case .dual: return "d.circle"
            }
        }
        var text: String{
            switch self{
            case .cap: return "Capacitive"
            case .tof: return "Time of Flight"
            case .dual: return "Dual"
            }
        }
        var color: Color {
            switch self{
            case .cap: return .blue
            case .tof: return .orange
            case .dual: return .green
            }
        }
        static func possibleOptions(options: String?) -> [TouchMode] {
            if let options = options {
                var results: [TouchMode] = []
                for item in options.split(separator: ",") {
                    if let option = TouchMode(rawValue: String(item)) {
                        results.append(option)
                    }
                }
                return results
            }
            return [.cap]
        }
    }

    private let selectedHandleSideKey = "SelectedHandleSideKey"
    private let selectedTouchModeKey = "selectedTouchModeKey"
    private var slientForChange: Bool = false
    private var updater: ((HandleSide?, TouchMode?) -> Void)?

    init() {
        if let selectedHandleSide = UserDefaults.standard.value(forKey: selectedHandleSideKey) as? String {
            self.selectedHandleSide = HandleSide(rawValue: selectedHandleSide) ?? .left
        }
        if let selectedTouchMode = UserDefaults.standard.value(forKey: selectedTouchModeKey) as? String {
            self.selectedTouchMode = TouchMode(rawValue: selectedTouchMode) ?? .cap
        }
    }

    func update(handlesideOptions param: String?) {
        possibleHandleSides = HandleSide.possibleOptions(options: param)
    }

    func update(touchmodeOptions param: String?) {
        possibleTouchModes = TouchMode.possibleOptions(options: param)
    }

    func silentUpdate(side: HandleSide) {
        self.slientForChange = true
        self.selectedHandleSide = side
    }

    func silentUpdate(mode: TouchMode) {
        self.slientForChange = true
        self.selectedTouchMode = mode
    }

    func updater(_ updater: @escaping (HandleSide?, TouchMode?) -> Void) {
        self.updater = updater
    }

    @Published var possibleHandleSides: [HandleSide] = [.left]
    @Published var possibleTouchModes: [TouchMode] = [.cap]
    @Published var selectedHandleSide: SuitcaseFeatures.HandleSide = .left {
        willSet {
            if slientForChange == false {
                updater?(newValue, nil)
            }
            slientForChange = false
        }
        didSet {
            UserDefaults.standard.setValue(selectedHandleSide.rawValue, forKey: selectedHandleSideKey)
            UserDefaults.standard.synchronize()
        }
    }

    @Published var selectedTouchMode: SuitcaseFeatures.TouchMode = .cap {
        willSet {
            if slientForChange == false {
                updater?(nil, newValue)
            }
            slientForChange = false
        }
        didSet {
            UserDefaults.standard.setValue(selectedTouchMode.rawValue, forKey: selectedTouchModeKey)
            UserDefaults.standard.synchronize()
        }
    }
}
