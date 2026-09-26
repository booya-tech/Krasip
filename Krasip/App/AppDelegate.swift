// AppDelegate.swift
// Krasip
// Starts the app controller at launch and keeps Krasip running when windows close.

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller: AppController

    override init() {
        #if DEBUG
        if PreviewRenderer.isRequested {
            controller = PreviewRenderer.makeController()
        } else if SimulationRunner.isRequested {
            controller = SimulationRunner.makeController()
        } else {
            controller = AppController()
        }
        #else
        controller = AppController()
        #endif
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if PreviewRenderer.isRequested {
            PreviewRenderer.run(app: controller)
            return
        }
        if SimulationRunner.isRequested {
            SimulationRunner.run(app: controller)
            return
        }
        #endif
        controller.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Opening the app again (Finder, Spotlight) shows Settings instead of doing nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            controller.showSettings()
        }
        return true
    }
}
