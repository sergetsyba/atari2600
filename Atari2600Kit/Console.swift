//
//  Console.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public class Atari2600: ObservableObject {
	private(set) public var cpu: MOS6507
	private(set) public var riot: MOS6532
	private(set) public var tia: TIA
	
	@Published
	public var cartridge: Data? = nil
	
	public init() {
		let cpu = MOS6507()
		
		self.cpu = cpu
		self.riot = MOS6532()
		self.tia = TIA(cpu: cpu)
		
		// TODO: move to CPU init
		self.cpu.bus = self
	}
	
	public func insertCartridge(fromFileAt url: URL) throws {
		self.cartridge = try Data(contentsOf: url)
		self.cpu.reset()
	}
}


// MARK: -
// MARK: Debugging
public extension Atari2600 {
	func stepProgram() {
		if self.tia.wsync {
			let cycles = self.tia.resumeLine()
			self.cpu.cycles += cycles / 3
		}
		
		let cycles = self.cpu.nextExecutionDuration
		self.tia.resume(cycles: cycles * 3)
		self.cpu.executeNextInstruction()
		self.cpu.cycles += cycles
	}
	
	func resumeProgram(until breakpoints: [Address]) {
		repeat {
			self.stepProgram()
		} while breakpoints.contains(self.cpu.programCounter) == false
	}
}


// MARK: -
public typealias Address = Int

protocol Bus {
	func read(at address: Address) -> Int
	func write(_ value: Int, at address: Address)
}


// MARK: -
// MARK: Memory segments
extension MOS6507: CPU {
}


// MARK: -
extension Atari2600: Bus {
	private static let mirrors: [Range<Address>: Range<Address>] = [
		// TIA
		0x0000..<0x0040: 0x0000..<0x0040,
		0x0040..<0x0080: 0x0000..<0x0040,
		// RAM
		0x0080..<0x0100: 0x0080..<0x0100,
		0x0180..<0x0200: 0x0080..<0x0100
	]
	
	private func unmirror(_ address: Address) -> Address {
		for (mirror, target) in Self.mirrors {
			if mirror.contains(address) {
				return address - (mirror.lowerBound - target.lowerBound)
			}
		}
		return address
	}
	
	func read(at address: Address) -> Int {
		let address = self.unmirror(address)
		
		if address < 0x0040 {
			return self.tia.read(at: address)
		} else if address < 0x0100 {
			return self.riot.read(at: address - 0x0080)
		} else {
			return Int(self.cartridge![address - 0xf000])
		}
	}
	
	func write(_ data: Int, at address: Address) {
		let address = self.unmirror(address)
		
		if address < 0x0040 {
			self.tia.write(data, at: address)
		} else if address < 0x0100 {
			self.riot.write(data, at: address - 0x0080)
		}
	}
}
