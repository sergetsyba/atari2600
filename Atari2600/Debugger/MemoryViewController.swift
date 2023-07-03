//
//  MemoryViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 12.6.2023.
//

import Cocoa
import Combine
import Atari2600Kit

class MemoryViewController: NSViewController {
	@IBOutlet private var tiaRegistersLabel: NSTextField!
	@IBOutlet private var ramLabel: NSTextField!
	@IBOutlet private var riotRegistersLabel: NSTextField!
	
	private var cancellables: Set<AnyCancellable> = []
	private let console: Atari2600 = .current
	
	convenience init() {
		self.init(nibName: "MemoryView", bundle: .main)
	}
	
	var labels: [NSTextField] {
		return [
			self.tiaRegistersLabel,
			self.ramLabel,
			self.riotRegistersLabel
		]
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		for label in self.labels {
			label.font = .regular
			label.textColor = .disabledControlTextColor
		}
		
		self.resetView()
		self.setUpSinks()
	}
}


// MARK: -
// MARK: UI updates
private extension MemoryViewController {
	func setUpSinks() {
		self.console.cpu.events
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in
				switch $0 {
				case .reset:
					self.resetView()
				case .sync:
					self.clearMemoryHighlights()
				}
			}.store(in: &self.cancellables)
		
		self.console.memory.events
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in
				switch $0 {
				case .read(_):
					break
				case .write(let address):
					self.highlightMemory(at: address)
				}
			}.store(in: &self.cancellables)
	}
	
	func resetView() {
		self.tiaRegistersLabel.attributedStringValue = NSAttributedString(
			string: String(memory: self.console.memory.tiaRegisters))
		self.ramLabel.attributedStringValue = NSAttributedString(
			string: String(memory: self.console.memory.ram))
		self.riotRegistersLabel.attributedStringValue = NSAttributedString(
			string: String(memory: self.console.memory.riotRegisters))
	}
	
	func highlightMemory(at address: Address) {
		let address = self.console.unmirror(address)
		let data = self.console.memory[address]
		
		if let (label, offset) = self.label(for: address) {
			let range = NSRange(location: offset * 3, length: 2)
			label[range] = String(word: data)
			label.addHighlight(in: range)
		} else {
			fatalError(String(format: "cannot highlight data at $%04x", address))
		}
	}
	
	func clearMemoryHighlights() {
		for label in self.labels {
			label.removeHighlights()
		}
	}
	
	func label(for address: Address) -> (NSTextField, Int)? {
		if (0x0000...0x003f).contains(address) {
			return (self.tiaRegistersLabel, address)
		}
		if (0x0080...0x00ff).contains(address) {
			return (self.ramLabel, address - 0x0080)
		}
		if (0x0280...0x29f).contains(address) {
			return (self.riotRegistersLabel, address - 0x0280)
		}
		return nil
	}
}


// MARK: -
// MARK: Data formatting
private extension String {
	init(word: Int) {
		self.init(format: "%02x", word)
	}
	
	init(word: UInt8) {
		self.init(format: "%02x", word)
	}
	
	init(memory: Memory) {
		self = memory.stride(by: 16)
			.map() { segment in
				return segment
					.map() { String(word: $0) }
					.joined(separator: " ")
			}.joined(separator: "\n")
	}
}


// MARK: -
// MARK: Convenience functionality
private extension NSTextField {
	subscript (range: NSRange) -> any StringProtocol {
		get {
			let string = self.attributedStringValue.string
			let start = string.index(string.startIndex, offsetBy: range.location)
			let end = string.index(start, offsetBy: range.length)
			
			return self.attributedStringValue.string[start..<end]
		}
		set {
			let string = NSMutableAttributedString(attributedString: self.attributedStringValue)
			string.replaceCharacters(in: range, with: String(newValue))
			
			self.attributedStringValue = string
		}
	}
	
	func addHighlight(in range: NSRange) {
		let string = NSMutableAttributedString(attributedString: self.attributedStringValue)
		string.setAttributes([
			.font: NSFont.emphasized,
			.foregroundColor: NSColor.labelColor
		], range: range)
		
		self.attributedStringValue = string
	}
	
	func removeHighlights() {
		let string = NSMutableAttributedString(attributedString: self.attributedStringValue)
		let range = NSRange(location: 0, length: string.length)
		string.removeAttribute(.font, range: range)
		
		self.attributedStringValue = string
	}
}
