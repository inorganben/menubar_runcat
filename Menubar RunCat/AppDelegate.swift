/*
 AppDelegate.swift
 Menubar RunCat

 Created by Takuto Nakamura on 2019/08/06.
 Copyright © 2019 Takuto Nakamura. All rights reserved.
*/

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var statusItem: NSStatusItem = {
        NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }()

    private lazy var statusController = StatusBarController(statusItem: statusItem,
                                                            loader: AnimationAssetLoader(),
                                                            metricServices: [CPUService()])

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController.start()
        setNotifications()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusController.shutdown()
    }

    @objc func receiveSleep(_ notification: NSNotification) {
        statusController.stop()
    }

    @objc func receiveWakeUp(_ notification: NSNotification) {
        statusController.resume()
    }

    private func setNotifications() {
        NSWorkspace.shared.notificationCenter
            .addObserver(self, selector: #selector(receiveSleep(_:)),
                         name: NSWorkspace.willSleepNotification,
                         object: nil)
        NSWorkspace.shared.notificationCenter
            .addObserver(self, selector: #selector(receiveWakeUp(_:)),
                         name: NSWorkspace.didWakeNotification,
                         object: nil)
    }
}
