import SwiftUI

struct StartScreen: View {
    @StateObject private var player1: PlayerCardViewModel
    @StateObject private var player2: PlayerCardViewModel
    @StateObject private var player3: PlayerCardViewModel
    @StateObject private var espManager = ESPPeripheralManager()

    @State private var isReadyToStart = false
    @State private var showSerialPicker = false
    @State private var lastSentBPMs: [Int] = [0, 0, 0]
    @State private var bpmValues: [Int] = [0,0,0]
//    @StateObject private var serialManager = SerialManager()
 

//    let manager = SerialManager()

    init(
        player1: PlayerCardViewModel = PlayerCardViewModel(
            id: 1,
            deviceUUID: UUID(uuidString: "5807F0AB-EC6C-5388-2F63-C1BA528E3950")!),
        player2: PlayerCardViewModel = PlayerCardViewModel(
            id: 2,
            deviceUUID: UUID(uuidString: "8AB98DEC-C997-F432-9873-85FD2DEBD170")!),
        player3: PlayerCardViewModel = PlayerCardViewModel(
            id: 3,
            deviceUUID: UUID(uuidString: "087AC373-A006-D6B6-26D3-4DD97728DAFF")!)
    ) {
        //You assign to _player1 once in init to tell SwiftUI “I’m giving you this object to manage,” and then you use player1 normally from there.
        _player1 = StateObject(wrappedValue: player1)
        _player2 = StateObject(wrappedValue: player2)
        _player3 = StateObject(wrappedValue: player3)
//        manager.refreshPorts()
//        manager.connect(to: manager.availablePorts.first!)
//        manager.send("motor on\r\n")
    }
    var body: some View {
        VStack(spacing: 40) {
            Text("Resonance")
                .font(.largeTitle)
                .bold()
            
            HStack(spacing: 30) {
                PlayerCardView(viewModel: player1)
                PlayerCardView(viewModel: player2)
                PlayerCardView(viewModel: player3)
            }
            
            if isReadyToStart {
                Text("All monitors connected. Starting...")
                    .font(.headline)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .onChange(of: [player1.heartRate, player2.heartRate, player3.heartRate]) { oldBPMs, newBPMs in
            if newBPMs != lastSentBPMs {
                espManager.sendGroupBPMs(newBPMs)
                lastSentBPMs = newBPMs
            }
        }
        .onChange(of: [player1.isConnected, player2.isConnected, player3.isConnected]) {
            isReadyToStart = player1.isConnected && player2.isConnected && player3.isConnected
            if isReadyToStart {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Transition to Game Screen goes here
                }
            }
        }
        Button("Turn on the vibes"){
//            serialManager.refreshPorts()
//            showSerialPicker = true
            
        }
        .buttonStyle(.plain)
        .padding()
//        .sheet(isPresented: $showSerialPicker){
//            SerialDevicePicker(serialManager: serialManager,
//                               isPresented: $showSerialPicker)
//        }
    }
}
#Preview {
    StartScreen(
        player1: PlayerCardViewModel(id: 1, deviceUUID: UUID()),
        player2: PlayerCardViewModel(id: 2, deviceUUID: UUID()),
        player3: PlayerCardViewModel(id: 3, deviceUUID: UUID())
    )
}

