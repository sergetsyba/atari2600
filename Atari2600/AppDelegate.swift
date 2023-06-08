//
//  AppDelegate.swift
//  Atari2600
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Cocoa
import SwiftUI
import Atari2600Kit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	private var windowControllers = Set<NSWindowController>()
	private var console: Atari2600 = .current
	
	@IBOutlet var window: NSWindow!
}


// MARK: -
// MARK: Main menu actions
extension AppDelegate {
	@IBAction func insertCartridgeMenuItemSelected(_ sender: NSMenuItem) {
		do {
			let url = URL(filePath: "/Users/Serge/Developer/Проекты/Atari2600/ROMS/Pac-Man.bin")
			try self.console.insertCartridge(fromFileAt: url)
		} catch {
			// TODO: handle error
			print(error)
		}
	}
	
	@IBAction func resetGame(_ sender: AnyObject) {
		self.console.cpu.reset()
	}
	
	@IBAction func stepMenuItemSelected(_ sender: AnyObject) {
		self.console.cpu.step()
	}
	
	@IBAction func debuggerMenuItemSelected(_ sender: AnyObject) {
		let windowController = DebuggerWindowController()
		self.showWindow(of: windowController)
	}
	
	func showWindow(with viewController: NSViewController) {
		let window = NSWindow(contentViewController: viewController)
		window.delegate = self
		
		let windowController = NSWindowController(window: window)
		windowController.showWindow(self)
		self.windowControllers.insert(windowController)
	}
}


// MARK: -
extension AppDelegate: NSWindowDelegate {
	func showWindow(of windowController: NSWindowController) {
		windowController.window?.delegate = self
		windowController.showWindow(self)
		self.windowControllers.insert(windowController)
	}
	
	func windowWillClose(_ notification: Notification) {
		if let window = notification.object as? NSWindow {
			self.windowControllers.remove(where: { $0.window == window })
		}
	}
}

private extension Set {
	mutating func remove(where condition: (Self.Element) -> Bool) {
		if let index = self.firstIndex(where: condition) {
			self.remove(at: index)
		}
	}
}


// MARK: -
// MARK: Convenience functionality
extension Atari2600 {
	static let current = Atari2600()
}
