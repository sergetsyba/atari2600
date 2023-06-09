//
//  CPUViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 9.6.2023.
//

import Cocoa
import Combine
import Atari2600Kit

class CPUViewController: NSViewController {
	@IBOutlet private var cyclesLabel: NSTextField!
	
	@IBOutlet private var accumulatorLabel: NSTextField!
	@IBOutlet private var indexXLabel: NSTextField!
	@IBOutlet private var indexYLabel: NSTextField!
	
	@IBOutlet private var statusNegativeLabel: NSTextField!
	@IBOutlet private var statusOverflowLabel: NSTextField!
	@IBOutlet private var statusBreakLabel: NSTextField!
	@IBOutlet private var statusDecimalModeLabel: NSTextField!
	@IBOutlet private var statusInterruptDisabledLabel: NSTextField!
	@IBOutlet private var statusZeroLabel: NSTextField!
	@IBOutlet private var statusCarryLabel: NSTextField!
	
	@IBOutlet private var stackPointerLabel: NSTextField!
	@IBOutlet private var programCounterLabel: NSTextField!
	
	private let console: Atari2600 = .current
	private let cpu: MOS6507 = Atari2600.current.cpu
	private var cancellables: Set<AnyCancellable> = []
	
	convenience init() {
		self.init(nibName: "CPUView", bundle: .main)
		self.title = "MOS6507"
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.updateSinks()
	}
	
	private var valueLabels: [NSTextField] {
		return [
			self.cyclesLabel,
			
			self.accumulatorLabel,
			self.indexXLabel,
			self.indexYLabel,
			
			self.statusNegativeLabel,
			self.statusOverflowLabel,
			self.statusBreakLabel,
			self.statusDecimalModeLabel,
			self.statusInterruptDisabledLabel,
			self.statusZeroLabel,
			self.statusCarryLabel,
			
			self.stackPointerLabel,
			self.programCounterLabel
		]
	}
}


// MARK: -
// MARK: UI updates
private extension CPUViewController {
	func updateSinks() {
		self.cpu.events
			.receive(on: DispatchQueue.main)
			.sink() {
				switch $0 {
				case .reset:
					for label in self.valueLabels {
						label.font = .regular
						label.textColor = .disabledControlTextColor
					}
					
				case .sync:
					for label in self.valueLabels {
						label.font = .regular
					}
				}
			}.store(in: &self.cancellables)
		
		self.console.cpu.$cycles
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.cyclesLabel.integerValue = $0 }
			.store(in: &self.cancellables)
		
		self.cpu.$accumulator
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.accumulatorLabel.wordValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.$x
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.indexXLabel.wordValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.$y
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.indexYLabel.wordValue = $0 }
			.store(in: &self.cancellables)
		
		self.cpu.status.$negative
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.statusNegativeLabel.boolValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.status.$overflow
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.statusOverflowLabel.boolValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.status.$break
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.statusBreakLabel.boolValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.status.$decimalMode
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.statusDecimalModeLabel.boolValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.status.$interruptDisabled
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.statusInterruptDisabledLabel.boolValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.status.$zero
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.statusZeroLabel.boolValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.status.$carry
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.statusCarryLabel.boolValue = $0 }
			.store(in: &self.cancellables)
		
		self.cpu.$stackPointer
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.stackPointerLabel.wordValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.$programCounter
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in self.programCounterLabel.addressValue = $0 }
			.store(in: &self.cancellables)
	}
}

extension NSFont {
	static let regular: NSFont = .monospacedSystemFont(ofSize: 11.0, weight: .regular)
	static let emphasized: NSFont = .monospacedSystemFont(ofSize: 11.0, weight: .bold)
}


// MARK: -
// MARK: Data formatting
private extension NSTextField {
	var boolValue: Bool {
		get { fatalError("NSTextField.boolValue") }
		set {
			self.font = .emphasized
			self.textColor = newValue
			? .labelColor
			: .disabledControlTextColor
		}
	}
	
	var cycleValue: UInt64 {
		get { fatalError("NSTextField.wordValue") }
		set {
			self.stringValue = "\(newValue)"
			self.font = .emphasized
			self.textColor = .labelColor
		}
	}
	
	var wordValue: Int {
		get { fatalError("NSTextField.wordValue") }
		set {
			self.stringValue = String(format: "%02x", newValue)
			self.font = .emphasized
			self.textColor = .labelColor
		}
	}
	
	var addressValue: Int {
		get { fatalError("NSTextField.addressValue") }
		set {
			self.stringValue = String(format: "$%04x", newValue)
			self.font = .emphasized
			self.textColor = .labelColor
		}
	}
}
