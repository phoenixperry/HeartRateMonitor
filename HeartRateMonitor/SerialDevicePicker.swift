////
////  SerialDevicePicker.swift
////  HeartRateMonitor
////
////  Created by Phoenix Perry on 18/04/2025.
////
//
//import SwiftUI
//import ORSSerial
//
//struct SerialDevicePicker: View {
//    @ObservedObject var serialManager: SerialManager
//    @Binding var isPresented: Bool
//    @Published var isConnecting: Bool = false
//    var body: some View {
//        NavigationView {
//            List(serialManager.availablePorts, id: \.name) { port in
//                Button(action: {
//                    serialManager.connect(to: port)
//                    isPresented = false
//                }) {
//                    VStack(alignment: .leading) {
//                        Text(port.name).bold()
//                        Text(port.path).font(.caption).foregroundColor(.secondary)
//                        
//                    }
//                }
//            }
//            .navigationTitle("Select Serial Port")
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") {
//                        isPresented = false
//                    }
//                }
//            }
//        }
//        .frame(minWidth: 400, minHeight: 300)
//    }
//}
//struct PreviewSerialPort: Identifiable {
//    let id = UUID()
//    let name: String
//    let path: String
//}
//struct PreviewSerialDevicePicker: View {
//    let mockPorts: [PreviewSerialPort]
//    
//    var body: some View {
//        NavigationView {
//            List(mockPorts) { port in
//                VStack(alignment: .leading) {
//                    Text(port.name).bold()
//                    Text(port.path).font(.caption).foregroundColor(.secondary)
//                }
//            }
//            .navigationTitle("Select Serial Port")
//        }
//    }
//}
//#Preview {
//    let mockPorts = [
//        PreviewSerialPort(name: "Cool Arduino 1", path: "/dev/tty.usbserial-123"),
//        PreviewSerialPort(name: "ESP32 Dancer", path: "/dev/tty.usbmodem-456")
//    ]
//    return PreviewSerialDevicePicker(mockPorts: mockPorts)
//}
//
//
