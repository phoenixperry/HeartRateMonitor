import SwiftUI

struct ContentView: View {
    @StateObject private var heartRateManager = HeartRateManager()
    @State private var scale: CGFloat = 1.0
    @State private var showingDeviceList = false
    
    var body: some View {
        VStack {
            // Title
            Text("Heart Rate Monitor")
                .font(.largeTitle)
                .padding(.bottom, 20)
            
            // Heart Image with Animation
            ZStack {
                Image("HeartImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .scaleEffect(scale)
                    .onChange(of: heartRateManager.heartRate) { oldValue, newValue in
                        if newValue > 0 {
                            animateHeart()
                        }
                    }
                
                Text("\(heartRateManager.heartRate) bpm")
                    .font(.custom("Futura-CondensedMedium", size: 28))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 20)
            
            // Device Info
            GroupBox(label: Text("Device Information").bold()) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(heartRateManager.connected)
                    Text(heartRateManager.bodyLocation)
                    Text(heartRateManager.manufacturer)
                }
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            .padding(.bottom, 20)
            
            // Control Buttons
            HStack(spacing: 20) {
                Button(action: {
                    if heartRateManager.isConnected {
                        heartRateManager.disconnectCurrentPeripheral()
                    } else {
                        showingDeviceList = true
                    }
                }) {
                    Text(heartRateManager.isConnected ? "Disconnect" : "Connect")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    if heartRateManager.isScanning {
                        heartRateManager.stopScanning()
                    } else {
                        heartRateManager.startScanning()
                        showingDeviceList = true
                    }
                }) {
                    Text(heartRateManager.isScanning ? "Stop Scan" : "Scan")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
        .sheet(isPresented: $showingDeviceList) {
            DeviceListView(heartRateManager: heartRateManager, isPresented: $showingDeviceList)
        }
    }
    
    // Animation function for heart beat
    func animateHeart() {
        if heartRateManager.heartRate > 0 {
            withAnimation(.easeInOut(duration: 0.1)) {
                scale = 1.1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    scale = 1.0
                }
            }
            
            // Set up next beat
            let interval = 60.0 / Double(heartRateManager.heartRate)
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                if heartRateManager.heartRate > 0 {
                    animateHeart()
                }
            }
        }
    }
}

// Device List View as a separate component
struct DeviceListView: View {
    @ObservedObject var heartRateManager: HeartRateManager
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            Text("Available Devices")
                .font(.headline)
                .padding()
            
            if heartRateManager.discoveredPeripherals.isEmpty {
                VStack {
                    ProgressView()
                        .padding()
                    Text("Scanning for devices...")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(heartRateManager.discoveredPeripherals, id: \.identifier) { peripheral in
                        Button(action: {
                            heartRateManager.connectToPeripheral(peripheral)
                            isPresented = false
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(peripheral.name ?? "Unknown Device")
                                        .font(.headline)
                                    Text(peripheral.identifier.uuidString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button(heartRateManager.isScanning ? "Stop Scanning" : "Start Scanning") {
                    if heartRateManager.isScanning {
                        heartRateManager.stopScanning()
                    } else {
                        heartRateManager.startScanning()
                    }
                }
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .onAppear {
            if !heartRateManager.isScanning {
                heartRateManager.startScanning()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
