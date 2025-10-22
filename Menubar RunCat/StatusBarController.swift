import Cocoa

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let loader: AnimationAssetLoader
    private var metricServices: [String: MetricService]
    private let preferences: PreferencesManager

    private var showUsageItem: NSMenuItem!
    private var animationsMenuItem: NSMenuItem!
    private var authorizeExternalItem: NSMenuItem!

    private var animationThemes: [AnimationTheme] = []
    private var currentTheme: AnimationTheme?
    private var runner: AnimationRunner?
    private var currentMetric: MetricService?
    private var metricSample: MetricSample = CPU.default
    private var externalDirectoryURL: URL?
    private var isAccessingExternalDirectory: Bool = false

    init(statusItem: NSStatusItem,
         loader: AnimationAssetLoader,
         metricServices: [MetricService],
         preferences: PreferencesManager = .shared) {
        self.statusItem = statusItem
        self.loader = loader
        self.metricServices = Dictionary(uniqueKeysWithValues: metricServices.map { ($0.identifier, $0) })
        self.preferences = preferences
        super.init()
    }

    deinit {
        releaseExternalDirectoryAccess()
    }

    func start() {
        configureStatusItem()
        restoreExternalDirectoryAccessIfNeeded()
        reloadAnimations()
        selectInitialAnimation()
        showUsageItem.state = preferences.showCPUUsage ? .on : .off
        updateUsageVisibility(preferences.showCPUUsage)
    }

    func stop() {
        runner?.stop()
        currentMetric?.stop()
    }

    func resume() {
        runner?.start()
        currentMetric?.start()
    }

    func shutdown() {
        stop()
        releaseExternalDirectoryAccess()
    }

    func toggleCPUVisibility() {
        let newValue = !preferences.showCPUUsage
        preferences.showCPUUsage = newValue
        updateUsageVisibility(newValue)
        showUsageItem.state = newValue ? .on : .off
    }

    private func configureStatusItem() {
        statusItem.button?.imagePosition = .imageTrailing
        if #available(macOS 10.15, *) {
            statusItem.button?.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        } else {
            statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        }

        showUsageItem = NSMenuItem(title: "Show CPU Usage", action: #selector(toggleShowUsage(_:)), keyEquivalent: "")
        showUsageItem.target = self

        animationsMenuItem = NSMenuItem(title: "Animations", action: nil, keyEquivalent: "")
        animationsMenuItem.submenu = NSMenu()

        let reloadItem = NSMenuItem(title: "Reload Animations", action: #selector(reloadAnimations(_:)), keyEquivalent: "")
        reloadItem.target = self

        authorizeExternalItem = NSMenuItem(title: "Select External Animations Folder…", action: #selector(selectExternalAnimationsFolder(_:)), keyEquivalent: "")
        authorizeExternalItem.target = self

        let aboutItem = NSMenuItem(title: "About Menubar RunCat", action: #selector(openAbout(_:)), keyEquivalent: "")
        aboutItem.target = self

        let quitItem = NSMenuItem(title: "Quit Menubar RunCat", action: #selector(terminateApp(_:)), keyEquivalent: "")
        quitItem.target = self

        menu.addItem(showUsageItem)
        menu.addItem(animationsMenuItem)
        menu.addItem(reloadItem)
        menu.addItem(authorizeExternalItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(aboutItem)
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleShowUsage(_ sender: NSMenuItem) {
        toggleCPUVisibility()
    }

    @objc private func reloadAnimations(_ sender: Any?) {
        reloadAnimations()
    }

    @objc private func selectExternalAnimationsFolder(_ sender: Any?) {
        presentExternalAnimationsFolderSelector()
    }

    @objc private func openAbout(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func terminateApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func presentExternalAnimationsFolderSelector() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Select the folder that contains custom animations."
        if let currentURL = externalDirectoryURL {
            panel.directoryURL = currentURL
        } else {
            let defaultURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".menubar_runcat", isDirectory: true)
            panel.directoryURL = defaultURL
        }
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        do {
            let bookmark = try url.bookmarkData(options: [.withSecurityScope],
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
            preferences.externalAnimationBookmark = bookmark
            updateExternalDirectory(url: url)
            reloadAnimations()
        } catch {
            NSLog("[Menubar RunCat] Failed to save external animation bookmark: %@", error.localizedDescription)
        }
    }

    private func reloadAnimations() {
        let additionalDirectories = externalDirectoriesForLoading()
        animationThemes = loader.loadThemes(additionalDirectories: additionalDirectories)
        rebuildAnimationsMenu()
        guard let current = currentTheme else { return }
        if animationThemes.contains(where: { $0.config.id == current.config.id }) == false {
            selectInitialAnimation()
        }
    }

    private func restoreExternalDirectoryAccessIfNeeded() {
        guard externalDirectoryURL == nil,
              let bookmark = preferences.externalAnimationBookmark else { return }
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmark,
                              options: [.withSecurityScope],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            if isStale {
                let refreshedBookmark = try url.bookmarkData(options: [.withSecurityScope],
                                                             includingResourceValuesForKeys: nil,
                                                             relativeTo: nil)
                preferences.externalAnimationBookmark = refreshedBookmark
            }
            updateExternalDirectory(url: url)
        } catch {
            NSLog("[Menubar RunCat] Failed to restore external animation access: %@", error.localizedDescription)
            preferences.externalAnimationBookmark = nil
        }
    }

    private func updateExternalDirectory(url: URL) {
        releaseExternalDirectoryAccess()
        externalDirectoryURL = url
        let granted = url.startAccessingSecurityScopedResource()
        if granted {
            isAccessingExternalDirectory = true
        } else {
            isAccessingExternalDirectory = false
            NSLog("[Menubar RunCat] Accessing external directory without security scope: %@", url.path)
        }
        ensureDirectoryExists(at: url)
    }

    private func releaseExternalDirectoryAccess() {
        if isAccessingExternalDirectory,
           let url = externalDirectoryURL {
            url.stopAccessingSecurityScopedResource()
        }
        externalDirectoryURL = nil
        isAccessingExternalDirectory = false
    }

    private func externalDirectoriesForLoading() -> [URL] {
        guard let url = externalDirectoryURL else { return [] }
        return [url]
    }

    private func ensureDirectoryExists(at url: URL) {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue == false {
                NSLog("[Menubar RunCat] External animation path is not a directory: %@", url.path)
            }
            return
        }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            NSLog("[Menubar RunCat] Failed to create directory at %@: %@", url.path, error.localizedDescription)
        }
    }

    private func rebuildAnimationsMenu() {
        guard let submenu = animationsMenuItem.submenu else { return }
        submenu.removeAllItems()
        if animationThemes.isEmpty {
            let item = NSMenuItem(title: "No animations found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
            return
        }
        for theme in animationThemes {
            let item = NSMenuItem(title: theme.config.displayName, action: #selector(selectAnimation(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.config.id
            if theme.config.id == currentTheme?.config.id {
                item.state = .on
            }
            submenu.addItem(item)
        }
    }

    private func selectInitialAnimation() {
        let preferredID = preferences.selectedAnimationID
        if let id = preferredID, let theme = animationThemes.first(where: { $0.config.id == id }) {
            applyTheme(theme)
        } else if let first = animationThemes.first {
            applyTheme(first)
        } else {
            loadFallbackTheme()
        }
    }

    @objc private func selectAnimation(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let theme = animationThemes.first(where: { $0.config.id == id }) else { return }
        applyTheme(theme)
        rebuildAnimationsMenu()
    }

    private func applyTheme(_ theme: AnimationTheme) {
        preferences.selectedAnimationID = theme.config.id
        currentTheme = theme

        runner?.stop()
        runner = AnimationRunner(frames: theme.frames, speedPolicy: theme.speedPolicy)
        runner?.delegate = self
        runner?.start()
        runner?.updateMetricValue(metricSample.value)

        connectMetric(for: theme.config.resolvedMetric())
        rebuildAnimationsMenu()
    }

    private func connectMetric(for identifier: String) {
        currentMetric?.stop()
        currentMetric?.onUpdate = nil
        guard let metric = metricServices[identifier] else { return }
        currentMetric = metric
        metric.onUpdate = { [weak self] sample in
            self?.handleMetricUpdate(sample)
        }
        metric.start()
    }

    private func handleMetricUpdate(_ sample: MetricSample) {
        metricSample = sample
        if preferences.showCPUUsage {
            statusItem.button?.title = sample.description
        }
        runner?.updateMetricValue(sample.value)
    }

    private func updateUsageVisibility(_ isVisible: Bool) {
        if isVisible {
            statusItem.button?.title = metricSample.description
        } else {
            statusItem.button?.title = ""
        }
    }

    private func loadFallbackTheme() {
        let frames = (0 ..< 5).compactMap { index -> NSImage? in
            guard let image = NSImage(named: "cat_page\(index)") else { return nil }
            image.size = NSSize(width: 28, height: 18)
            image.isTemplate = true
            return image
        }
        guard frames.isEmpty == false else { return }
        let config = AnimationConfig(id: "fallback",
                                     displayName: "Fallback Cat",
                                     frameDirectory: nil,
                                     filePattern: nil,
                                     frameCount: nil,
                                     frameExtension: nil,
                                     frameNames: nil,
                                     frameSize: nil,
                                     template: true,
                                     metric: "cpu",
                                     speedPolicy: nil)
        let theme = AnimationTheme(config: config, frames: frames, speedPolicy: SpeedPolicy(config: nil))
        applyTheme(theme)
    }
}

extension StatusBarController: AnimationRunnerDelegate {
    func animationRunner(_ runner: AnimationRunner, didRender frame: NSImage) {
        statusItem.button?.image = frame
    }

    func animationRunnerDidRequestFrameSize(_ runner: AnimationRunner, size: NSSize) {
        statusItem.button?.image?.size = size
    }
}
