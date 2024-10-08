//
//  PeripheralDelegateHandler.swift
//
//
//  Created by Igor on 15.07.24.
//

import Foundation
import CoreBluetooth

extension BluetoothLEManager {
    
    // Class to handle CB Peripheral Delegate
    class PeripheralDelegate: NSObject, CBPeripheralDelegate {
       
        /// Service registration for a specific action.
        private let service: ServiceRegistration<Void>

        /// Initializes the manager with a logger and sets up the service registration.
        ///
        /// - Parameter logger: The logger instance to be used for logging.
        init(logger: ILogger) {
            service = .init(type: .discovering, logger: logger)
        }
       
        /// Called when the peripheral discovers services
        ///
        /// - Parameters:
        ///   - peripheral: The `CBPeripheral` instance that discovered services
        ///   - error: An optional error if the discovery failed
        public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            Task{
                if let error = error {
                    await service.handleResult(for: peripheral, result: .failure(BluetoothLEManager.Errors.discoveringServices(peripheral.getName, error)))
                    
                } else{
                        await service.handleResult(for: peripheral, result: .success(Void()))
                    }
            }
        }

        /// Initiates the discovery of services on the specified peripheral
        ///
        /// - Parameter peripheral: The `CBPeripheral` instance on which to discover services
        /// - Returns: An array of `CBService` representing the services supported by the peripheral
        /// - Throws: An error if service discovery fails
        @MainActor
        public func discoverServices(for peripheral: CBPeripheral) async throws {
            return try await withCheckedThrowingContinuation { continuation in
                Task{
                    let id = peripheral.getId
                    let name = peripheral.getName
                    try await service.register(to: id, name: name, with: continuation)
                    guard peripheral.isConnected else{
                        await service.handleResult(for: peripheral, result: .failure(BluetoothLEManager.Errors.discoveringServices(peripheral.getName, nil)))
                        return
                    }
                    peripheral.discoverServices(nil)
                }
            }
        }
        
        public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {

        }
    }
}
