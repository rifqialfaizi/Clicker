//
//  ClickerApp.swift
//  Clicker
//
//  Created by Rifqi Alfaizi on 03/06/26.
//

import SwiftUI

@main
struct ClickerApp: App {
    @StateObject private var viewModel = ClickerViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
