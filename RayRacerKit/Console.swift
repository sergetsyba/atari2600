//
//  Console.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Foundation
import Combine

public class Atari2600: ObservableObject {
	private var eventSubject = PassthroughSubject<Event, Never>()
	private var debugEventSubject = PassthroughSubject<DebugEvent, Never>()
	
	private(set) public var cpu: MOS6507!
	private(set) public var riot: MOS6532!
	private(set) public var tia: TIA!
	private(set) public var cartridge: Data? = nil
	private(set) public var frame = Data(count: 262 * 228)
	
	public var switches: Switches = .random()
	public var joystic = Joystick()
	
	public init() {
		self.cpu = MOS6507(bus: self)
		self.riot = MOS6532(ports: (self.joystic, self))
		self.tia = TIA(screen: self)
	}
	
	// Resets internal state.
	public func reset() {
		self.cpu.reset()
		self.riot.reset()
		self.tia.reset()
		
		self.eventSubject.send(.reset)
	}
	
	public func setSwitch(_ switch: Switches, on: Bool) {
		if on {
			self.switches.insert(`switch`)
		} else {
			self.switches.remove(`switch`)
		}
	}
	
	public func insertCartridge(_ data: Data) {
		self.cartridge = data
		self.reset()
	}
}


// MARK: -
// MARK: Events
public extension Atari2600 {
	enum Event {
		case reset
		case frame
	}
	
	var events: some Publisher<Event, Never> {
		return self.eventSubject
	}
}

public extension Atari2600 {
	enum DebugEvent {
		case `break`
		case resume
	}
	
	var debugEvents: some Publisher<DebugEvent, Never> {
		return self.debugEventSubject
	}
}


// MARK: -
// MARK: Debugging
public extension Atari2600 {
	func stepProgram() {
		// when stepping a CPU instruction and WSYNC is on, advance TIA to
		// horizontal sync and execute the next CPU instruction
		if self.tia.waitingHorizontalSync {
			let cycles = self.tia.advanceClockToHorizontalSync()
			self.riot.advanceClock(cycles: cycles / 3)
		}
		
		self.executeNextCPUInstruction()
		self.debugEventSubject.send(.break)
	}
	
	func stepScanLine() {
		let scanLine = self.scanLine
		repeat {
			// when stepping a scan line and WSYNC is on, advance TIA to
			// horizontal sync but break before the next CPU instruction
			if self.tia.waitingHorizontalSync {
				let cycles = self.tia.advanceClockToHorizontalSync()
				self.riot.advanceClock(cycles: cycles / 3)
			} else {
				self.executeNextCPUInstruction()
			}
		} while self.scanLine == scanLine
		
		self.debugEventSubject.send(.break)
	}
	
	func stepFrame() {
		var clock1 = self.tia.screenClock
		var clock2 = self.tia.screenClock
		
		// keep executing CPU instructions until frame clock decreases
		repeat {
			clock1 = clock2
			if self.tia.waitingHorizontalSync {
				let cycles = self.tia.advanceClockToHorizontalSync()
				self.riot.advanceClock(cycles: cycles / 3)
			}
			
			self.executeNextCPUInstruction()
			clock2 = self.tia.screenClock
		} while clock1 < clock2
		
		self.debugEventSubject.send(.break)
	}
	
	func resumeProgram(until breakpoints: [Int]) {
		repeat {
			self.stepProgram()
		} while breakpoints.contains(self.cpu.programCounter) == false
		
		self.debugEventSubject.send(.break)
	}
	
	private func executeNextCPUInstruction() {
		let cycles = self.cpu.nextInstructionDuration
		self.tia.advanceClock(cycles: cycles * 3)
		self.riot.advanceClock(cycles: cycles)
		self.cpu.executeNextInstruction()
	}
}


// MARK: -
extension Atari2600: Addressable {
	public func unmirror(_ address: Int) -> Int {
		if (0x0040..<0x0080).contains(address) {
			return address - 0x40
		}
		if (0x5000..<0x6000).contains(address) {
			return address + 0xa000
		}
		return address
	}
	
	public func read(at address: Int) -> Int {
		let address = self.unmirror(address)
		if (0x0000..<0x0040).contains(address) {
			return self.tia.read(at: address)
		}
		if (0x0080..<0x0100).contains(address) {
			let address = address - 0x0080
			let data = self.riot.memory[address]
			return Int(data)
		}
		if (0x0280..<0x0300).contains(address) {
			let address = address - 0x0280
			return self.riot.read(at: address)
		}
		
		let data = self.cartridge?[address - 0xf000]
		?? .random(in: 0x00...0xff)
		
		return Int(data)
	}
	
	public func write(_ data: Int, at address: Int) {
		let address = self.unmirror(address)
		if (0x0000..<0x0040).contains(address) {
			return self.tia.write(data, at: address)
		}
		if (0x0080..<0x0100).contains(address) {
			let address = address - 0x0080
			return self.riot.memory[address] = UInt8(data)
		}
		if (0x0280..<0x0300).contains(address) {
			let address = address - 0x0280
			return self.riot.write(data, at: address)
		}
		
		let message = String(format: "Ignoring write at address $%04x", address)
		print(message)
	}
}


// MARK: - Console switches
extension Atari2600 {
	public struct Switches: OptionSet {
		public static let reset = Switches(rawValue: 1 << 0)
		public static let select = Switches(rawValue: 1 << 1)
		public static let color = Switches(rawValue: 1 << 3)
		public static let difficulty0 = Switches(rawValue: 1 << 6)
		public static let difficulty1 = Switches(rawValue: 1 << 7)
		
		public var rawValue: Int
		
		public static func random() -> Switches {
			let value: Int = .random(in: 0x00...0xff)
			return Switches(rawValue: value)
		}
		
		public init(rawValue: Int) {
			self.rawValue = rawValue
		}
	}
}

extension Atari2600: MOS6532.Port {
	public func read() -> Int {
		// when switches for `select` and `reset` are on, corresponding
		// bit values are set to 0
		return self.switches.rawValue ^ 0x03
	}
	
	public func write(_ data: Int) {
		// port B is supposed to be read-only, but can be written to
		// nonetheless; writing sets the 3 unassigned bits
		self.switches.rawValue |= data & 0x34
	}
}


// MARK: - Joystick
extension Atari2600 {
	public struct Joystick {
	}
}

extension Atari2600.Joystick: MOS6532.Port {
	public func read() -> Int {
		return 0
	}
	
	public mutating func write(_ data: Int) {
	}
}


// MARK: -
extension Atari2600: Screen {
	public var height: Int {
		return 262
	}
	
	public var width: Int {
		return 228
	}
	
	private var scanLine: Int {
		return self.tia.screenClock / self.width
	}
	
	public func sync() {
		self.eventSubject.send(.frame)
	}
	
	public func write(color: Int) {
		if self.tia.screenClock < self.frame.count {
			self.frame[self.tia.screenClock] = UInt8(color) >> 1
		}
	}
	
	// FIXME: remove
	public var frameClock: Int {
		return self.tia.screenClock
	}
}
