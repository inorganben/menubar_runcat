import Cocoa

struct AnimationFrameSize: Codable {
    let width: Double?
    let height: Double?

    var size: NSSize? {
        guard let width, let height else { return nil }
        return NSSize(width: width, height: height)
    }
}

struct SpeedPolicyConfig: Codable {
    let type: String
    let minInterval: Double?
    let maxInterval: Double?
    let interval: Double?
}

struct AnimationConfig: Codable {
    let id: String
    let displayName: String
    let frameDirectory: String?
    let filePattern: String?
    let frameCount: Int?
    let frameExtension: String?
    let frameNames: [String]?
    let frameSize: AnimationFrameSize?
    let template: Bool?
    let metric: String?
    let speedPolicy: SpeedPolicyConfig?

    func resolvedFrameExtension() -> String {
        frameExtension ?? "png"
    }

    func resolvedMetric() -> String {
        (metric?.isEmpty == false) ? metric! : "cpu"
    }
}

enum SpeedPolicy {
    case cpuLinear(minInterval: TimeInterval, maxInterval: TimeInterval)
    case fixed(interval: TimeInterval)

    init(config: SpeedPolicyConfig?) {
        guard let config = config else {
            self = .cpuLinear(minInterval: 0.08, maxInterval: 0.4)
            return
        }
        switch config.type {
        case "fixed":
            let interval = config.interval ?? 0.2
            self = .fixed(interval: max(0.01, interval))
        default:
            let minInterval = max(0.02, config.minInterval ?? 0.08)
            let maxInterval = max(minInterval, config.maxInterval ?? 0.4)
            self = .cpuLinear(minInterval: minInterval, maxInterval: maxInterval)
        }
    }
}

struct AnimationTheme {
    let config: AnimationConfig
    let frames: [NSImage]
    let speedPolicy: SpeedPolicy
}
