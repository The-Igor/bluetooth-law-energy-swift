//
//  RegistrationStream.swift
//
//  Manages Bluetooth Low Energy (BLE) peripheral discovery stream.
//
//  Created by Igor on 22.07.24.
//

import Combine
import CoreBluetooth

extension BluetoothLEManager {
    
    /// An actor responsible for the registration and streaming of discovered Bluetooth peripherals.
    actor StreamRegistration {
        
        /// A dictionary to keep track of subscribers using their UUIDs.
        private var subscribers: [UUID: PeripheralsContinuation] = [:]
        
        /// A subject to broadcast changes in the subscriber count.
        private let subscriberCountSubject = PassthroughSubject<Int, Never>()
        
        /// A list to store the discovered peripherals.
        @MainActor
        private var discoveredPeripherals: [CBPeripheral] = []
        
        /// A type alias for an asynchronous stream continuation specific to an array of CBPeripheral.
        public typealias PeripheralsContinuation = AsyncStream<[CBPeripheral]>.Continuation
        
        /// A publisher to provide external updates on the subscriber count changes.
        public var subscriberCountPublisher: AnyPublisher<Int, Never> {
            subscriberCountSubject.eraseToAnyPublisher()
        }
        
        /// A computed property to get the current number of subscribers.
        public var count: Int {
            return subscribers.count
        }
        
        /// Provides an asynchronous stream of arrays of discovered peripherals.
        public var stream: AsyncStream<[CBPeripheral]> {
            createPeripheralStream()
        }
        
        private let logger: ILogger
        
        /// Initializes the StreamRegistration with a logger.
        ///
        /// - Parameter logger: An instance conforming to `ILogger` for logging purposes.
        init(logger: ILogger) {
            self.logger = logger
        }
        
        deinit {
            subscribers.forEach { (key, value) in
                value.finish()
            }
            discoveredPeripherals = []
        }
        
        /// Registers a new subscriber and immediately provides the current list of peripherals.
        ///
        /// - Parameters:
        ///   - id: The UUID of the subscriber to register.
        ///   - continuation: The `PeripheralsContinuation` to handle the discovered peripherals.
        public func register(with id: UUID, and continuation: PeripheralsContinuation) async {
            subscribers[id] = continuation
            continuation.yield(await discoveredPeripherals)
            subscriberCountSubject.send(count)
        }
        
        /// Unregisters a subscriber and updates the subscriber count.
        ///
        /// - Parameter id: The UUID of the subscriber to unregister.
        public func unregister(with id: UUID) {
            subscribers.removeValue(forKey: id)
            subscriberCountSubject.send(count)
        }
        
        /// Notifies all subscribers with the updated list of discovered peripherals.
        ///
        /// - Parameter peripherals: The updated list of discovered `CBPeripheral` instances.
        @MainActor
        public func notifySubscribers(_ peripherals: [CBPeripheral]) async {
            await discoveredPeripherals = peripherals
            for continuation in await subscribers.values {
                continuation.yield(peripherals)
            }
        }
        
        /// Creates and returns an `AsyncStream` of peripherals, managing the lifecycle events.
        ///
        /// - Returns: An `AsyncStream` of `[CBPeripheral]` to provide peripheral data.
        private func createPeripheralStream() -> AsyncStream<[CBPeripheral]> {
            AsyncStream<[CBPeripheral]> { [weak self] continuation in
                guard let self = self else { return }
                Task {
                    let id = UUID()
                    await self.register(with: id, and: continuation)
                    continuation.onTermination = { [weak self] _ in
                        guard let self = self else { return }
                        Task {
                            await self.unregister(with: id)
                        }
                    }
                }
            }
        }
    }
}
