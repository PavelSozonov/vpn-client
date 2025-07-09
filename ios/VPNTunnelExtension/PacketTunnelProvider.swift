import NetworkExtension
import libXray

class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let configURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.vpnclient")?.appendingPathComponent("config.json") else {
            completionHandler(NSError(domain: "VPN", code: -1, userInfo: nil))
            return
        }
        libxray_start(configURL.path)
        completionHandler(nil)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        libxray_stop()
        completionHandler()
    }
}
