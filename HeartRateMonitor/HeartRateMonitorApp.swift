import SwiftUI

@main
struct HeartRateMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Declare shared ESP manager
    let espManager = ESPPeripheralManager()

    // Declare shared player VMs
    let player1: PlayerCardViewModel
    let player2: PlayerCardViewModel
    let player3: PlayerCardViewModel

    init() {
        // Initialize players with the shared ESP manager
        player1 = PlayerCardViewModel(
            id: 1,
            deviceUUID: UUID(uuidString: "5807F0AB-EC6C-5388-2F63-C1BA528E3950")!,
            espManager: espManager
        )

        player2 = PlayerCardViewModel(
            id: 2,
            deviceUUID: UUID(uuidString: "939617A2-BF34-DA9C-A319-13A252EB4684")!,
            espManager: espManager
        )

        player3 = PlayerCardViewModel(
            id: 3,
            deviceUUID: UUID(uuidString: "087AC373-A006-D6B6-26D3-4DD97728DAFF")!,
            espManager: espManager
        )

        // Assign espManager to AppDelegate
        appDelegate.espManager = espManager
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                player1: player1,
                player2: player2,
                player3: player3,
                espManager: espManager
            )
        }
    }
}
