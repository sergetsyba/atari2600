//
//  DebuggerWindow.swift
//  Atari2600
//
//  Created by Serge Tsyba on 27.5.2023.
//

import AppKit
import Combine
import Atari2600Kit

class DebuggerWindowController: NSWindowController {
	@IBOutlet private var toolbar: NSToolbar!
	
	@IBOutlet private var assemblyContainerView: NSView!
	@IBOutlet private var cpuContainerView: NSView!
	@IBOutlet private var memoryContainerView: NSView!
	@IBOutlet private var timerContainerView: NSView!
	
	private var assemblyViewController = AssemblyViewController()
	private let cpuViewController = CPUViewController()
	private let memoryViewController = MemoryViewController()
	private let timerViewController = TimerViewController()
	
	private let console: Atari2600 = .current
	private var cancellables: Set<AnyCancellable> = []
	
	init() {
		super.init(window: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override var windowNibName: NSNib.Name? {
		return "DebuggerWindow"
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		
		self.assemblyContainerView.setContentView(self.assemblyViewController.view)
		self.cpuContainerView.setContentView(self.cpuViewController.view, layout: .centerHorizontally)
		self.memoryContainerView.setContentView(self.memoryViewController.view)
		self.timerContainerView.setContentView(self.timerViewController.view, layout: .centerHorizontally)
		
		self.setUpSinks()
	}
}


// MARK: -
// MARK: Target actions
private extension DebuggerWindowController {
	@IBAction func removeAllBreakpointsMenuItemSelected(_ sender: NSMenuItem) {
		self.assemblyViewController.clearBreakpoints()
	}
	
	@IBAction func breakpointMenuItemSelected(_ sender: NSMenuItem) {
		self.assemblyViewController.showBreakpoint(sender.tag)
	}
	
	@IBAction func resumeProgramMenuItemSelected(_ sender: AnyObject) {
		let breakpoints = self.assemblyViewController.breakpoints
		let queue = DispatchQueue.global(qos: .background)
		queue.async() {
			self.console.resumeProgram(until: breakpoints)
		}
	}
}


// MARK: -
// MARK: UI updates
private extension DebuggerWindowController {
	func setUpSinks() {
		self.cancellables.insert(
			self.console.events
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] in
					switch $0 {
					case .reset:
						self.updateToolbarItems()
					}
				})
		
		self.cancellables.insert(
			// NOTE: delay lets toolbar item to get deselected
			self.assemblyViewController.$breakpoints
				.delay(for: 0.01, scheduler: RunLoop.current)
				.sink() { [unowned self] in
					self.updateBreakpointsToolbarItemMenu(breakpoints: $0)
				}
		)
	}
	
	func updateToolbarItems() {
		let cartridgeInserted = self.console.cartridge != nil
		self.toolbar[.stepItem]?.isEnabled = cartridgeInserted
		self.toolbar[.resumeItem]?.isEnabled = cartridgeInserted
		self.toolbar[.resetItem]?.isEnabled = cartridgeInserted
	}
	
	func updateBreakpointsToolbarItemMenu(breakpoints: [Address]) {
		let removeAllMenuItem = NSMenuItem(
			title: "Remove All",
			action: #selector(self.removeAllBreakpointsMenuItemSelected(_:)),
			keyEquivalent: "")
		
		let menu = NSMenu()
		menu.items = [
			removeAllMenuItem,
			.separator()
		]
		
		breakpoints.map() { self.createBreakpointMenuItem(breakpoint: $0) }
			.sorted(by: { $0.tag < $1.tag })
			.forEach(menu.addItem(_:))
		
		let toolbarItem = self.toolbar[.breakpointsItem] as? NSMenuToolbarItem
		toolbarItem?.menu = menu
		toolbarItem?.isEnabled = breakpoints.count > 0
	}
	
	func createBreakpointMenuItem(breakpoint: Address) -> NSMenuItem {
		let menuItem = NSMenuItem()
		menuItem.tag = breakpoint
		menuItem.attributedTitle = NSAttributedString(
			string: String(address: breakpoint),
			attributes: [
				.font: NSFont.monospacedRegular
			])
		
		menuItem.action = #selector(self.breakpointMenuItemSelected(_:))
		return menuItem
	}
}


// MARK: -
// MARK: Toolbar management
extension DebuggerWindowController: NSToolbarDelegate {
	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		switch itemIdentifier {
		case .breakpointsItem:
			// NOTE: NSMenuToolbarItem is not supported in Interface Builder
			let toolbarItem = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem.image = NSImage(symbolName: "Breakpoint", variableValue: 1.0)
			toolbarItem.label = "Breakpoints"
			toolbarItem.isEnabled = false
			
			return toolbarItem
			
		default:
			// NOTE: all other toolbar items are loaded from Xib
			return nil
		}
	}
	
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [
			.breakpointsItem,
			.resumeItem,
			.stepItem,
			.resetItem,
			.space,
			.flexibleSpace
		]
	}
	
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [
			.breakpointsItem,
			.space,
			.resumeItem,
			.stepItem,
			.flexibleSpace,
			.resetItem
		]
	}
}

private extension NSToolbarItem.Identifier {
	static let breakpointsItem = NSToolbarItem.Identifier("BreakpointsItem")
	static let resumeItem = NSToolbarItem.Identifier("ResumeItem")
	static let stepItem = NSToolbarItem.Identifier("StepItem")
	static let resetItem = NSToolbarItem.Identifier("ResetItem")
}


// MARK: -
// MARK: Convenience functionality
private extension NSToolbar {
	subscript (identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
		return self.items.first(where: { $0.itemIdentifier == identifier })
	}
}
