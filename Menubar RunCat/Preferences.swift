import Foundation

final class PreferencesManager {
    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let selectedAnimationID = "selectedAnimationID"
        static let showCPUUsage = "showCPUUsage"
        static let externalAnimationBookmark = "externalAnimationBookmark"
    }

    var selectedAnimationID: String? {
        get { defaults.string(forKey: Keys.selectedAnimationID) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Keys.selectedAnimationID)
            } else {
                defaults.removeObject(forKey: Keys.selectedAnimationID)
            }
        }
    }

    var showCPUUsage: Bool {
        get {
            if defaults.object(forKey: Keys.showCPUUsage) == nil {
                return false
            }
            return defaults.bool(forKey: Keys.showCPUUsage)
        }
        set {
            defaults.set(newValue, forKey: Keys.showCPUUsage)
        }
    }

    var externalAnimationBookmark: Data? {
        get { defaults.data(forKey: Keys.externalAnimationBookmark) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Keys.externalAnimationBookmark)
            } else {
                defaults.removeObject(forKey: Keys.externalAnimationBookmark)
            }
        }
    }
}
