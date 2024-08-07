//
//  Addressable.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 20.7.2024.
//

public protocol Addressable<Address> {
	associatedtype Address
	
	func read(at address: Address) -> Int
	mutating func write(_ value: Int, at address: Address)
}
