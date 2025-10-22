import Cocoa

final class AnimationAssetLoader {
    private let bundle: Bundle
    private let fileManager: FileManager

    init(bundle: Bundle = .main,
         fileManager: FileManager = .default) {
        self.bundle = bundle
        self.fileManager = fileManager
    }

    func loadThemes(additionalDirectories: [URL] = []) -> [AnimationTheme] {
        var themeByID: [String: AnimationTheme] = [:]
        for directory in searchDirectories(additionalDirectories: additionalDirectories) {
            for theme in loadThemes(in: directory) {
                themeByID[theme.config.id] = theme
            }
        }
        return themeByID.values.sorted { $0.config.displayName.localizedCaseInsensitiveCompare($1.config.displayName) == .orderedAscending }
    }

    private func searchDirectories(additionalDirectories: [URL]) -> [URL] {
        var directories: [URL] = []
        if let bundleURL = bundle.resourceURL?.appendingPathComponent("Animations", isDirectory: true),
           fileManager.fileExists(atPath: bundleURL.path) {
            directories.append(bundleURL)
        }
        for url in additionalDirectories {
            if fileManager.fileExists(atPath: url.path) {
                directories.append(url)
            }
        }
        return directories
    }

    private func loadThemes(in directoryURL: URL) -> [AnimationTheme] {
        guard let enumerator = fileManager.enumerator(at: directoryURL,
                                                     includingPropertiesForKeys: [.isDirectoryKey],
                                                     options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
            return []
        }

        var themes: [AnimationTheme] = []
        for case let folderURL as URL in enumerator {
            guard isDirectory(url: folderURL) else { continue }
            if let theme = loadTheme(at: folderURL) {
                themes.append(theme)
            }
        }
        return themes
    }

    private func loadTheme(at folderURL: URL) -> AnimationTheme? {
        let configURL = folderURL.appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: configURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let config = try? decoder.decode(AnimationConfig.self, from: data) else { return nil }
        let frames = loadFrames(for: config, in: folderURL)
        guard frames.isEmpty == false else { return nil }
        let speedPolicy = SpeedPolicy(config: config.speedPolicy)
        return AnimationTheme(config: config, frames: frames, speedPolicy: speedPolicy)
    }

    private func loadFrames(for config: AnimationConfig, in folderURL: URL) -> [NSImage] {
        let frameDirectoryURL: URL
        if let frameDirectory = config.frameDirectory {
            frameDirectoryURL = folderURL.appendingPathComponent(frameDirectory, isDirectory: true)
        } else {
            frameDirectoryURL = folderURL
        }

        let frameNames: [String]
        if let explicitNames = config.frameNames, !explicitNames.isEmpty {
            frameNames = explicitNames
        } else if let pattern = config.filePattern, let count = config.frameCount {
            frameNames = (0 ..< count).map { "\(pattern)\($0).\(config.resolvedFrameExtension())" }
        } else {
            frameNames = loadAllFileNames(in: frameDirectoryURL, withExtension: config.resolvedFrameExtension()).sorted()
        }

        var frames: [NSImage] = []
        let size = config.frameSize?.size
        for name in frameNames {
            let url: URL
            if name.contains("/") {
                url = frameDirectoryURL.appendingPathComponent(name)
            } else {
                url = frameDirectoryURL.appendingPathComponent(name)
            }
            guard let image = NSImage(contentsOf: url) else { continue }
            if let size {
                image.size = size
            }
            image.isTemplate = config.template ?? false
            frames.append(image)
        }
        return frames
    }

    private func loadAllFileNames(in directoryURL: URL, withExtension ext: String) -> [String] {
        guard let contents = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        return contents.filter { $0.pathExtension.lowercased() == ext.lowercased() }.map { $0.lastPathComponent }
    }

    private func isDirectory(url: URL) -> Bool {
        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return resourceValues?.isDirectory ?? false
    }

}
