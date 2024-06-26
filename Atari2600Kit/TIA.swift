//
//  TIA.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 29.6.2023.
//

import CoreGraphics
import Combine
import Cocoa

protocol CPU {
	var ready: Bool { get set }
}

public class TIA {
	private var eventSubject = PassthroughSubject<Event, Never>()
	
	private var cpu: CPU
	init(cpu: CPU) {
		self.cpu = cpu
	}
	
	public var data = Data(count: 228*262)
	
	var cycle = 0
	
	// Vertical sync register.
	var vsync: Bool = false {
		didSet {
			if self.vsync == true {
				self.eventSubject.send(.frame)
				self.cycle = 0
			}
		}
	}
	// Vertical blank register.
	var vblank: Bool = false
	// Wait for horizontal sync register.
	var wsync: Bool = false
	
	// Player 0 and missile 0 color and luminosity register.
	var colup0: Int = 0x00
	// Player 1 and missile 1 color and luminosity register.
	var colup1: Int = 0x00
	// Playfield and ball color and luminosity register.
	var colupf: Int = .randomWord
	// Background color and luminosity register.
	var colubk: Int = .randomWord
	
	var pf0: Int = .randomWord {
		didSet {
			self.playfiled &= 0xffff0
			self.playfiled |= self.pf0 >> 4
		}
	}
	var pf1: Int = .randomWord {
		didSet {
			self.playfiled &= 0xff00f
			self.playfiled |= self.pf1 << 4
		}
	}
	var pf2: Int = .randomWord {
		didSet {
			self.playfiled &= 0x00fff
			self.playfiled |= self.pf2
		}
	}
	var ctrlpf: Int = 0x00
	
	var playfiled: Int = 0x00
	
	var grp0: Int = .randomWord
	var nusiz0: Int = .randomWord
	var refp0: Int = .randomWord
	
	/// Reset sync strobe register.
	/// Writing any value resets color clock to its value at the beginning of the current scanline.
	var rsync: Bool {
		get { return false }
		set { self.cycle -= self.cycle % 228 }
	}
	
	func advanceClock(cycles: Int) {
		for _ in 0..<cycles {
			self.drawPoint()
			self.cycle += 1
		}
	}
	
	func advanceLine() {
		let cycles = 228 - (self.cycle % 228)
		self.advanceClock(cycles: cycles)
		self.wsync = false
	}
}


// MARK: -
// MARK: Drawing
extension TIA {
	func drawPoint() {
		let y = self.cycle / 228 - (3+37)
		let x = self.cycle % 228 - 68
		
		guard y >= 0 && y < 192
				&& x >= 0 else {
			return
		}
		
		// draw background
		self.data[self.cycle] = UInt8(self.colubk) / 2
		self.drawPlayfield(x: x, y: y)
	}
	
	func drawPlayfield(x: Int, y: Int) {
		if x < 160/2 {
			// left playfield side
			if self.playfiled[x/4] {
				let color = self.ctrlpf[1]
				? self.colup0
				: self.colupf
				
				self.data[self.cycle] = UInt8(color) / 2
			}
		} else {
			// right playfield side
			var bit = x/4-20
			if self.ctrlpf[0] {
				// mirrorred right playfield side
				bit = 20-bit
			}
			
			if self.playfiled[bit] {
				let color = self.ctrlpf[1]
				? self.colup1
				: self.colupf
				
				self.data[self.cycle] = UInt8(color) / 2
			}
		}
	}
}

// MARK: -
// MARK: Bus integration
extension TIA: Bus {
	public func read(at address: Address) -> Int {
		return 0x00
	}
	
	public func write(_ data: Int, at address: Address) {
		switch address {
		case 0x00:
			self.vsync = data[1]
		case 0x01:
			self.vblank = data[1]
		case 0x02:
			self.wsync = true
		case 0x03:
			self.rsync = true
			
		case 0x06:
			self.colup0 = data
		case 0x07:
			self.colup1 = data
		case 0x08:
			self.colupf = data
		case 0x09:
			self.colubk = data
		case 0x0a:
			self.ctrlpf = data
		case 0x0d:
			self.pf0 = data
		case 0x0e:
			self.pf1 = Int(reversingBits: data)
		case 0x0f:
			self.pf2 = data
		default:
			break
		}
	}
}

// MARK: -
// MARK: Debugging
public extension TIA {
	enum Event {
		case frame
	}
	
	var events: some Publisher<Event, Never> {
		return self.eventSubject
	}
}

public extension Int {
	static let frameSize = 262 * 228
	
	init(reversingBits value: Int) {
		self = 0
		for bit in 0..<8 {
			self[bit] = value[7-bit]
		}
	}
	
	subscript (range: Range<Int>) -> [Bool] {
		return range.map({ self[$0] })
	}
}


private extension CGRect {
	static let ntsc = CGRect(x: 0.0, y: 0.0, width: 160.0, height: 192.0)
}


extension CGColor {
	static var random: CGColor {
		return CGColor(
			red: .random(in: 0.0...1.0),
			green: .random(in: 0.0...1.0),
			blue: .random(in: 0.0...1.0),
			alpha: 1.0)
	}
}

private extension UInt32 {
	subscript(bit: Int) -> Bool {
		get {
			let mask: UInt32 = 0x01 << bit
			return self & mask == mask
		}
		set {
			let mask: UInt32 = 0x01 << bit
			if newValue {
				self |= mask
			} else {
				self &= ~mask
			}
		}
	}
}
