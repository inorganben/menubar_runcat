import Cocoa

protocol AnimationRunnerDelegate: AnyObject {
    func animationRunner(_ runner: AnimationRunner, didRender frame: NSImage)
    func animationRunnerDidRequestFrameSize(_ runner: AnimationRunner, size: NSSize)
}

final class AnimationRunner {
    weak var delegate: AnimationRunnerDelegate?

    private var frames: [NSImage]
    private var speedPolicy: SpeedPolicy
    private var timer: Timer?
    private var currentIndex: Int = 0
    private var currentInterval: TimeInterval

    init(frames: [NSImage], speedPolicy: SpeedPolicy, defaultInterval: TimeInterval = 0.2) {
        self.frames = frames
        self.speedPolicy = speedPolicy
        self.currentInterval = defaultInterval
    }

    func update(frames: [NSImage], speedPolicy: SpeedPolicy) {
        stop()
        self.frames = frames
        self.speedPolicy = speedPolicy
        currentIndex = 0
        if let first = frames.first {
            delegate?.animationRunnerDidRequestFrameSize(self, size: first.size)
            delegate?.animationRunner(self, didRender: first)
        }
        scheduleTimer(interval: currentInterval)
    }

    func start() {
        guard timer == nil else { return }
        if let first = frames.first {
            delegate?.animationRunnerDidRequestFrameSize(self, size: first.size)
            delegate?.animationRunner(self, didRender: first)
        }
        scheduleTimer(interval: currentInterval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func updateMetricValue(_ value: Double) {
        let interval = intervalForValue(value)
        guard abs(interval - currentInterval) > 0.005 else { return }
        currentInterval = interval
        reschedule()
    }

    private func intervalForValue(_ value: Double) -> TimeInterval {
        switch speedPolicy {
        case let .fixed(interval):
            return interval
        case let .cpuLinear(minInterval, maxInterval):
            let clampedValue = max(0.0, min(100.0, value))
            let normalized = clampedValue / 100.0
            let delta = maxInterval - minInterval
            return maxInterval - (delta * normalized)
        }
    }

    private func scheduleTimer(interval: TimeInterval) {
        guard frames.isEmpty == false else { return }
        timer?.invalidate()
        timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func reschedule() {
        guard timer != nil else { return }
        scheduleTimer(interval: currentInterval)
    }

    private func advanceFrame() {
        guard frames.isEmpty == false else { return }
        currentIndex = (currentIndex + 1) % frames.count
        let frame = frames[currentIndex]
        delegate?.animationRunner(self, didRender: frame)
    }
}
