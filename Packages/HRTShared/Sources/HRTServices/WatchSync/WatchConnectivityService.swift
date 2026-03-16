import Foundation
import HRTModels

#if canImport(WatchConnectivity)
import WatchConnectivity

@MainActor
public final class WatchConnectivityService: NSObject, ObservableObject {
    public static let shared = WatchConnectivityService()

    @Published public var receivedEvents: [DoseEvent] = []
    @Published public var isReachable: Bool = false

    private override init() {
        super.init()
    }

    public func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    #if os(iOS)
    public func syncToWatch(snapshot: WatchSyncSnapshot) {
        guard WCSession.default.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let dict: [String: Any] = ["snapshot": data]
        try? WCSession.default.updateApplicationContext(dict)
    }
    #endif

    #if os(watchOS)
    public func sendEventToPhone(_ event: DoseEvent) {
        guard WCSession.default.activationState == .activated else { return }
        let payload = DoseEventPayload(from: event)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let dict: [String: Any] = ["newEvent": data]
        WCSession.default.transferUserInfo(dict)
    }
    #endif
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        Task { @MainActor in
            isReachable = reachable
        }
    }

    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["newEvent"] as? Data,
              let payload = try? JSONDecoder().decode(DoseEventPayload.self, from: data),
              let event = payload.toDoseEvent() else { return }
        Task { @MainActor in
            receivedEvents.append(event)
        }
    }
    #endif

    #if os(watchOS)
    nonisolated public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data,
              let snapshot = try? JSONDecoder().decode(WatchSyncSnapshot.self, from: data) else { return }
        Task { @MainActor in
            receivedEvents = snapshot.events.compactMap { $0.toDoseEvent() }
        }
    }
    #endif
}
#endif
