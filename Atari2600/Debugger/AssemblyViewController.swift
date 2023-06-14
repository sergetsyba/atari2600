//
//  AssemblyViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 5.6.2023.
//

import Cocoa
import Combine
import Atari2600Kit

class AssemblyViewController: NSViewController {
	@IBOutlet private var tableView: NSTableView!
	
	private let console: Atari2600 = .current
	private var cancellables: Set<AnyCancellable> = []
	
	private var program: [(MOS6507.Address, MOS6507.Instruction)]? {
		didSet {
			self.tableView.reloadData()
		}
	}
	
	private var highlightedRow: Int? = nil {
		didSet {
			self.updateRowSelection()
		}
	}
	
	convenience init() {
		self.init(nibName: "AssemblyView", bundle: .main)
		self.title = "Program assembly"
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.updateTableColumnWidths()
		self.updateSinks()
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		
		// making tableview first responder changes selection color to active
		self.view.window?
			.makeFirstResponder(self.tableView)
	}
}


// MARK: -
// MARK: UI updates
private extension AssemblyViewController {
	static let font: NSFont = .monospacedSystemFont(ofSize: 11.0, weight: .regular)
	
	func updateSinks() {
		self.console.$cartridge
			.sink() { [unowned self] in
				if let _ = $0 {
					self.program = console.cpu.decodeROM()
					self.highlightedRow = nil
				} else {
					self.program = nil
				}
			}.store(in: &self.cancellables)
		
		self.console.cpu.$programCounter
			.sink() { [unowned self] address in
				self.highlightedRow = self.program?
					.firstIndex(where: { $0.0 == address })
			}.store(in: &self.cancellables)
	}
	
	func updateTableColumnWidths() {
		let sizes = ["$0000", "adc", "($a4),Y"]
			.map() {
				return $0.size(withAttributes: [
					.font: Self.font
				])
			}
		
		self.tableView.tableColumns[0].width = sizes[0].width * 1.5
		self.tableView.tableColumns[1].width = sizes[1].width
		self.tableView.tableColumns[2].width = sizes[2].width
	}
	
	func updateRowSelection() {
		if let row = self.highlightedRow {
			self.tableView.selectRowIndexes([row], byExtendingSelection: false)
			self.tableView.ensureRowVisible(row)
		} else {
			for row in self.tableView.selectedRowIndexes {
				self.tableView.deselectRow(row)
			}
		}
	}
}


// MARK: -
// MARK: Table view management
extension AssemblyViewController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		return self.program?.count ?? 0
	}
}

extension AssemblyViewController: NSTableViewDelegate {
	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
		return row == self.highlightedRow
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let cellView = tableView.makeView(withIdentifier: .cell, owner: nil) as? AssemblyTableCellView,
			  let (address, instruction) = self.program?[row] else {
			return nil
		}
		
		switch tableColumn {
		case tableView.tableColumns[0]:
			cellView.label.stringValue = String(format: "$%04x", address)
		case tableView.tableColumns[1]:
			cellView.label.stringValue = "\(instruction.mnemonic)"
		case tableView.tableColumns[2]:
			cellView.label.stringValue = String(format: instruction.mode.formatPattern, instruction.operand)
		default:
			return nil
		}
		
		cellView.label.font = Self.font
		return cellView
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let cell = NSUserInterfaceItemIdentifier("AssemblyTableCellView")
}


// MARK: -
// MARK: Table view cells
class AssemblyTableCellView: NSTableCellView {
	@IBOutlet var label: NSTextField!
}


// MARK: -
// MARK: Data formatting
private extension MOS6507.AddressingMode {
	var formatPattern: String {
		switch self {
		case .implied:
			return ""
		case .immediate:
			return "#$%02x"
		case .absolute, .relative:
			return "$%04x"
		case .absoluteX:
			return "$%04x,X"
		case .absoluteY:
			return "$%04x,Y"
		case .zeroPage:
			return "$%02x"
		case .zeroPageX:
			return "$%02x,X"
		case .zeroPageY:
			return "$%02x,Y"
		case .indirectX:
			return "($%02x,X)"
		case .indirectY:
			return "($%02x),Y"
		}
	}
}


// MARK: -
// MARK: Convenience functionality
private extension NSScrollView {
	func isVisible(rect: CGRect) -> Bool {
		let viewRect = self.documentVisibleRect
		let insets = self.contentInsets
		
		return rect.minY >= viewRect.minY + insets.top
		&& rect.maxY <= viewRect.maxY - insets.bottom
	}
	
	func scroll(to point: NSPoint, animationDuration duration: CGFloat) {
		NSAnimationContext.beginGrouping()
		NSAnimationContext.current.duration = duration
		
		self.contentView.animator()
			.setBoundsOrigin(point)
		
		NSAnimationContext.endGrouping()
	}
}

private extension NSTableView {
	func ensureRowVisible(_ row: Int) {
		let scrollView = self.enclosingScrollView!
		let rowRect = self.rect(ofRow: row)
		if scrollView.isVisible(rect: rowRect) {
			return
		}
		
		let viewRect = scrollView.documentVisibleRect
		let insets = scrollView.contentInsets
		let viewHieght = viewRect.height - (insets.top + insets.bottom)
		
		// scroll such that row ends up vertically at 1/3 of view's
		// visible content height
		let offset = (viewHieght - rowRect.height) / 3 + insets.top
		let point = NSPoint(x: rowRect.minX, y: rowRect.minY - offset)
		scrollView.scroll(to: point, animationDuration: 0.25)
	}
}