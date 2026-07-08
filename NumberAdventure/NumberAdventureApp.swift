//
//  NumberAdventureApp.swift
//  NumberAdventure
//
//  Created by hondajunya on 2026/06/27.
//

import SwiftUI

@main
struct NumberAdventureApp: App {
    init() {
        AdManager.shared.initialize()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
