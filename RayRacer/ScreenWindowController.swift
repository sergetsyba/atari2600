//
//  ScreenWindowController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 30.6.2023.
//

import Cocoa
import Combine
import RayRacerKit

class ScreenWindowController: NSWindowController {
	@IBOutlet private var imageView: NSImageView!
	
	private let console: Atari2600 = .current
	private var cancellables: Set<AnyCancellable> = []
	
	convenience init() {
		self.init(window: nil)
	}
	
	override var windowNibName: NSNib.Name? {
		return "ScreenWindow"
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		self.setUpSinks()
	}
}


// MARK: -
// MARK: UI updates
private extension ScreenWindowController {
	func setUpSinks() {
		self.cancellables.insert(
			self.console.events
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] in
					switch $0 {
					case .frame:
						self.updateImage()
					default:
						break
					}
				})
		
		self.cancellables.insert(
			self.console.debugEvents
				.receive(on: DispatchQueue.main)
				.sink() {
					switch $0 {
					case .break:
						self.updateImage()
					default:
						break
					}
				})
	}
	
	private func updateImage() {
		let size = NSSize(width: self.console.width, height: self.console.height)
		self.imageView.image = NSImage(ntscData: self.console.frame, size: size)
	}
}


// MARK: -
// MARK: Convenience functionality
private extension NSImage {
	convenience init(ntscData data: Data, size: NSSize) {
		let provider = CGDataProvider(data: data as CFData)
		let rawImage = CGImage(
			width: Int(size.width),
			height: Int(size.height),
			bitsPerComponent: 8,
			bitsPerPixel: 8,
			bytesPerRow: Int(size.width),
			space: .ntsc,
			bitmapInfo: CGBitmapInfo(),
			provider: provider!,
			decode: nil,
			shouldInterpolate: false,
			intent: .defaultIntent)
		
		let image = rawImage?.cropping(to: CGRect(
			origin: CGPoint(x: 68.0, y: 20.0),
			size: CGSize(width: size.width - 68, height: size.height - 50.0)))
		
		self.init(cgImage: image!, size: size)
	}
}

private extension CGColorSpace {
	static let ntsc: CGColorSpace = {
		var colorSpace: CGColorSpace!
		palette.withUnsafeBufferPointer() {
			colorSpace = CGColorSpace(
				indexedBaseSpace: CGColorSpaceCreateDeviceRGB(),
				last: palette.count/3 - 1,
				colorTable: $0.baseAddress!)
		}
		return colorSpace
	}()
}

extension NSColor {
	convenience init(ntscColor color: Int) {
		let index = (color / 2) * 3
		
		self.init(
			red: CGFloat(palette[index]) / 255.0,
			green: CGFloat(palette[index + 1]) / 255.0,
			blue: CGFloat(palette[index + 2]) / 255.0,
			alpha: 1.0)
	}
}

private let palette: [UInt8] = [
	0x00, 0x00, 0x00,
	0x1a, 0x1a, 0x1a,
	0x39, 0x39, 0x39,
	0x5b, 0x5b, 0x5b,
	0x7e, 0x7e, 0x7e,
	0xa2, 0xa2, 0xa2,
	0xc7, 0xc7, 0xc7,
	0xed, 0xed, 0xed,
	
	0x19, 0x02, 0x00,
	0x39, 0x1f, 0x00,
	0x5d, 0x41, 0x00,
	0x82, 0x64, 0x00,
	0xa6, 0x88, 0x00,
	0xcb, 0xad, 0x01,
	0xf2, 0xd2, 0x18,
	0xfe, 0xfa, 0x40,
	
	0x37, 0x00, 0x00,
	0x5e, 0x08, 0x00,
	0x83, 0x26, 0x00,
	0xa9, 0x49, 0x00,
	0xcf, 0x6c, 0x00,
	0xf5, 0x8f, 0x18,
	0xfe, 0xb4, 0x38,
	0xfd, 0xdf, 0x6f,
	
	0x47, 0x00, 0x00,
	0x73, 0x00, 0x00,
	0x98, 0x14, 0x01,
	0xbe, 0x31, 0x16,
	0xe4, 0x52, 0x34,
	0xfe, 0x76, 0x57,
	0xfe, 0x9c, 0x81,
	0xfe, 0xc6, 0xbb,
	
	0x44, 0x00, 0x09,
	0x70, 0x00, 0x1f,
	0x96, 0x05, 0x3f,
	0xbb, 0x23, 0x63,
	0xe1, 0x45, 0x85,
	0xfe, 0x67, 0xaa,
	0xfe, 0x8c, 0xd7,
	0xfe, 0xb7, 0xf6,
	
	0x2d, 0x00, 0x4a,
	0x57, 0x00, 0x67,
	0x7d, 0x06, 0x8c,
	0xa1, 0x21, 0xb1,
	0xa1, 0x43, 0xd7,
	0xed, 0x64, 0xfe,
	0xfe, 0x8a, 0xf6,
	0xfe, 0xb5, 0xf7,
	
	0x0d, 0x01, 0x81,
	0x33, 0x00, 0xa2,
	0x55, 0x0e, 0xc9,
	0x78, 0x2c, 0xf0,
	0x9c, 0x4e, 0xfe,
	0xc3, 0x73, 0xfe,
	0xeb, 0x98, 0xfe,
	0xfe, 0xc0, 0xfa,
	
	0x07, 0x00, 0x91,
	0x0b, 0x05, 0xbd,
	0x28, 0x21, 0xe4,
	0x48, 0x42, 0xfe,
	0x6b, 0x64, 0xfe,
	0x90, 0x8a, 0xfe,
	0xb7, 0xb0, 0xfe,
	0xdf, 0xd8, 0xfe,
	
	0x04, 0x00, 0x72,
	0x01, 0x1d, 0xab,
	0x03, 0x3c, 0xd6,
	0x20, 0x5e, 0xfd,
	0x40, 0x81, 0xfe,
	0x64, 0xa6, 0xfe,
	0x89, 0xce, 0xfe,
	0xaf, 0xf6, 0xfe,
	
	0x00, 0x10, 0x3b,
	0x00, 0x31, 0x6e,
	0x00, 0x55, 0xa2,
	0x05, 0x79, 0xc8,
	0x23, 0x9d, 0xef,
	0x44, 0xc2, 0xfe,
	0x68, 0xe9, 0xfe,
	0xf8, 0xfe, 0xfe,
	
	0x00, 0x1f, 0x02,
	0x00, 0x43, 0x26,
	0x00, 0x69, 0x57,
	0x00, 0x8d, 0x7a,
	0x19, 0xb1, 0x9e,
	0x3a, 0xd7, 0xc3,
	0x5d, 0xfe, 0xe9,
	0x86, 0xfe, 0xff,
	
	0x00, 0x24, 0x03,
	0x01, 0x4a, 0x06,
	0x00, 0x70, 0x0d,
	0x0a, 0x95, 0x2b,
	0x28, 0xba, 0x4c,
	0x49, 0xe0, 0x6e,
	0x6c, 0xfe, 0x92,
	0x96, 0xfe, 0xb5,
	
	0x00, 0x21, 0x02,
	0x01, 0x46, 0x04,
	0x08, 0x6b, 0x01,
	0x27, 0x90, 0x00,
	0x4a, 0xb5, 0x09,
	0x6a, 0xdb, 0x27,
	0x8e, 0xfe, 0x4a,
	0xba, 0xfe, 0x69,
	
	0x00, 0x15, 0x01,
	0x10, 0x36, 0x00,
	0x30, 0x59, 0x00,
	0x53, 0x7e, 0x01,
	0x76, 0xa3, 0x00,
	0x9a, 0xc8, 0x00,
	0xbf, 0xee, 0x1d,
	0xe8, 0xfe, 0x3e,
	
	0x1a, 0x02, 0x00,
	0x3b, 0x1f, 0x00,
	0x5e, 0x41, 0x00,
	0x84, 0x63, 0x00,
	0xa8, 0x88, 0x00,
	0xce, 0xad, 0x00,
	0xf4, 0xd2, 0x18,
	0xfe, 0xfa, 0x40,
	
	0x38, 0x00, 0x00,
	0x5f, 0x08, 0x00,
	0x84, 0x28, 0x01,
	0xaa, 0x49, 0x00,
	0xcf, 0x6c, 0x00,
	0xf6, 0x8f, 0x17,
	0xfe, 0xb4, 0x38,
	0xfd, 0xdf, 0x71
]
