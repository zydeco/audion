/*
Copyright 2020-2021 Panic Inc.

This file is part of Audion.

Audion is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Audion is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Audion.  If not, see <https://www.gnu.org/licenses/>.
*/

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    class var shared: AppDelegate { return NSApp.delegate as! AppDelegate }
    
    var preferencesWindowController: NSWindowController? = nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [AudionVolumePrefKey: 0.5])
        setupAppMenuItems()
    }

    public var appSupportDirectory: URL? {
        get {
            let fileManager = FileManager.default
            let appSupportURLs = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            if appSupportURLs.count > 0 {
                let appSupportURL = appSupportURLs[0]
                let facesURL = appSupportURL.appendingPathComponent("Audion").appendingPathComponent("Faces")

                do {
                    if !fileManager.fileExists(atPath: facesURL.path) {
                        try fileManager.createDirectory(at: facesURL, withIntermediateDirectories: true, attributes: nil)
                    }
                } catch {
                    return nil
                }

                return facesURL
            }

            return nil
        }
    }

    @IBAction func openFacesFolder(_ sender: Any?) {
        if let appSupportDirectory = self.appSupportDirectory {
            NSWorkspace.shared.open(appSupportDirectory)
        }
    }

    @IBAction func showPrefs(_ sender: Any?) {
        if self.preferencesWindowController == nil {

            if let viewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("AppearancePrefPane")) as? AppearancePrefsViewController {

                viewController.view.translatesAutoresizingMaskIntoConstraints = false

                let window = NSWindow(contentRect: NSRect.zero, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: true)
                window.title = "Preferences"
                window.contentViewController = viewController
                preferencesWindowController = NSWindowController(window: window)

                NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: OperationQueue.main) { _ in
                    self.preferencesWindowController = nil
                }

                window.center()
            }
        }

        self.preferencesWindowController?.window?.makeKeyAndOrderFront(self)
    }
    
    private var viewController: ViewController? {
        for window in NSApp.windows {
            if let viewController = window.contentViewController as? ViewController {
                return viewController
            }
        }
        return nil
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        return viewController?.open(url: URL(fileURLWithPath: filename)) ?? false
    }
    
    
    @IBAction func openAppleScript(_ sender: Any?) {
        guard let appName = (sender as? NSMenuItem)?.title,
              let url = URL(string: "osascript:\(appName)") else {
            return
        }
        
        let _ = viewController?.open(url: url)
    }
    
    @IBOutlet var appleScriptAppsMenuItem: NSMenuItem?
    @IBOutlet var dockMenu: NSMenu?

    private func setupAppMenuItems() {
        let appleScriptAppsSubmenu = appleScriptAppsMenuItem?.submenu
        appleScriptAppsSubmenu?.removeAllItems()
        let bundleIdentifiers = ["com.apple.Music", "com.spotify.client", "com.apple.iTunes"]
        let workspace = NSWorkspace.shared
        for bundleIdentifier in bundleIdentifiers {
            if let appUrl = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                let appName = appUrl.deletingPathExtension().lastPathComponent
                let menuItem = NSMenuItem(title: appName, action: #selector(AppDelegate.openAppleScript(_:)), keyEquivalent: "")
                menuItem.image = workspace.icon(forFile: appUrl.path)
                appleScriptAppsSubmenu?.addItem(menuItem)
            }
        }
        dockMenu?.addItem(appleScriptAppsMenuItem!.copy() as! NSMenuItem)
    }
    
    func markMenuItem(forAppName appName: String?) {
        for menuItem in appleScriptAppsMenuItem?.submenu?.items ?? [] {
            menuItem.state = (menuItem.title == appName) ? .on : .off
        }
    }
}

@objc (AudionApplication)
class AudionApplication: NSApplication {
    override var nextResponder: NSResponder? {
        get {
            if self.mainWindow?.contentViewController as? ViewController != nil {
                return super.nextResponder
            }
            else {
                for window in NSApp.windows {
                    if let viewController = window.contentViewController as? ViewController {
                        return viewController
                    }
                }

                return super.nextResponder
            }
        }
        set {
            super.nextResponder = newValue
        }
    }

    override func orderFrontStandardAboutPanel(options optionsDictionary: [NSApplication.AboutPanelOptionKey : Any] = [:]) {
        if ( NSEvent.modifierFlags.contains(.option) )
        {
            let year = Calendar.current.component(.year, from: Date())
            let alert = NSAlert()
            alert.messageText = "Were you really expecting an Easter egg in " + String(year) + "?"
            alert.informativeText = "I mean, this is open source, so it's not like I can hide it."

            alert.addButton(withTitle: "Of course I was!")
            alert.addButton(withTitle: "Not really…")

            let result = alert.runModal()

            if result == .alertFirstButtonReturn {
                let subalert = NSAlert()
                subalert.messageText = "You're right, software should be more fun."
                subalert.informativeText = "I thought really hard about what kinds of easter eggs I should add, but it just didn't feel appropriate given the state of the world right now. Fortunately, Audion itself is already plenty fun."

                subalert.addButton(withTitle: "😢")

                subalert.runModal()
            } else {
                super.orderFrontStandardAboutPanel(options: optionsDictionary)
            }
        } else {
            super.orderFrontStandardAboutPanel(options: optionsDictionary)
        }
    }
}

