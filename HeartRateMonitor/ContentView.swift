import SwiftUI

struct ContentView: View {
    let player1: PlayerCardViewModel
    let player2: PlayerCardViewModel
    let player3: PlayerCardViewModel
    let espManager: ESPPeripheralManager

    var body: some View {
        StartScreen(
            player1: player1,
            player2: player2,
            player3: player3,
            espManager: espManager
        )
    }
}

#Preview {
    let espManager = ESPPeripheralManager()

    let player1 = PlayerCardViewModel(id: 1, deviceUUID: UUID(), espManager: espManager)
    let player2 = PlayerCardViewModel(id: 2, deviceUUID: UUID(), espManager: espManager)
    let player3 = PlayerCardViewModel(id: 3, deviceUUID: UUID(), espManager: espManager)

    return ContentView(
        player1: player1,
        player2: player2,
        player3: player3,
        espManager: espManager
    )
}
