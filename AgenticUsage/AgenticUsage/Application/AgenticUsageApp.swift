//
//  AgenticUsageApp.swift
//  AgenticUsage
//
//  Created by Leo Ho on 2026/2/15.
//

import AgenticCore
import ComposableArchitecture
import SwiftUI

@main
struct AgenticUsageApp: App {
    @State private var store = Store(initialState: MenuBarFeature.State()) {
        MenuBarFeature()
    } withDependencies: {
        $0.gitHubAPIClient = .live
        $0.oAuthService = .live
        $0.keychainService = .live
        $0.pasteboard = .live
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: self.store)
        } label: {
            Label("AgenticUsage", systemImage: "chart.bar.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
