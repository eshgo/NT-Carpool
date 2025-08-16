//
//  NT_CarpoolApp.swift
//  NT Carpool
//
//  Created by Eshan Godbole   on 6/18/25.
//

import SwiftUI

@main
struct NT_CarpoolApp: App {
    @State private var currentUser: User? = nil  // ← Add this

    var body: some Scene {
        WindowGroup {
            CarpoolGroupInputView(currentUser: $currentUser)  // ← Pass binding
        }
    }
}

