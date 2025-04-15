//
//  HeartRateMonitorApp.swift
//  HeartRateMonitor
//
//  Created by Phoenix Perry on 05/03/2025.
//

import SwiftUI

@main
struct HeartRateMonitorApp: App {
    let persistenceController = PersistenceController.shared

//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//        }
//    }
//}
        var body: some Scene {
            WindowGroup {
                ContentView()
            }
        }
    }
