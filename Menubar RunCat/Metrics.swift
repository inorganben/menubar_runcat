import Foundation

typealias MetricSample = (value: Double, description: String)

protocol MetricService: AnyObject {
    var identifier: String { get }
    var onUpdate: ((MetricSample) -> Void)? { get set }
    func start()
    func stop()
}

final class CPUService: MetricService {
    let identifier: String = "cpu"
    var onUpdate: ((MetricSample) -> Void)?

    private let sampler = CPU()
    private var timer: Timer?
    private let interval: TimeInterval

    init(interval: TimeInterval = 2.0) {
        self.interval = interval
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.emitSample()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        emitSample()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func emitSample() {
        let info = sampler.currentUsage()
        onUpdate?(info)
    }
}
