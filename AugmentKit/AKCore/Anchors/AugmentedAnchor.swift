//
//  AugmentedAnchor.swift
//  AugmentKit
//
//  MIT License
//
//  Copyright (c) 2018 JamieScanlon
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import ARKit
import Foundation
import ModelIO

/**
 A generic AR object that can be placed in the AR world. These can be created and given to the AR engine to render in the AR world.
 */
public class AugmentedAnchor: AKAugmentedAnchor {
    
    /**
     Returns "AugmentedAnchor"
     */
    public static var type: String {
        return "AugmentedAnchor"
    }
    /**
     The location of the anchor
     */
    public var worldLocation: AKWorldLocation
    /**
     The locaiton of the anchor
     */
    public var heading: AKHeading = NorthHeading()
    /**
     The `MDLAsset` associated with the entity.
     */
    public var asset: MDLAsset
    /**
     A unique, per-instance identifier
     */
    public var identifier: UUID?
    /**
     An array of `AKEffect` objects that are applied by the renderer
     */
    public var effects: [AnyEffect<Any>]?
    /**
     Specified a perfered renderer to use when rendering this enitity. Most will use the standard PBR renderer but some entities may prefer a simpiler renderer when they are not trying to achieve the look of real-world objects. Defaults to the PBR renderer.
     */
    public var shaderPreference: ShaderPreference = .pbr
    /**
     An `ARAnchor` that will be tracked in the AR world by `ARKit`
     */
    public var arAnchor: ARAnchor?
    /**
     Initialize a new object with an `MDLAsset` and an `AKWorldLocation`
     - Parameters:
        - withModelAsset: The `MDLAsset` associated with the entity.
        - at: The location of the anchor
     */
    public init(withModelAsset asset: MDLAsset, at location: AKWorldLocation) {
        self.asset = asset
        self.worldLocation = location
    }
    /**
     Set the identifier for this instance
     - Parameters:
        - _: A UUID
     */
    public func setIdentifier(_ identifier: UUID) {
        self.identifier = identifier
    }
    /**
     Sets a new `arAnchor`
     - Parameters:
        - _: An `ARAnchor`
     */
    public func setARAnchor(_ arAnchor: ARAnchor) {
        self.arAnchor = arAnchor
        if identifier == nil {
            identifier = arAnchor.identifier
        }
        worldLocation.transform = arAnchor.transform
    }
    
}

/// :nodoc:
extension AugmentedAnchor: CustomDebugStringConvertible, CustomStringConvertible {
    
    /// :nodoc:
    public var description: String {
        return debugDescription
    }
    
    /// :nodoc:
    public var debugDescription: String {
        let myDescription = "<AugmentedAnchor: \(Unmanaged.passUnretained(self).toOpaque())> worldLocation: \(worldLocation), identifier:\(identifier?.debugDescription ?? "None"), effects: \(effects?.debugDescription ?? "None"), arAnchor: \(arAnchor?.debugDescription ?? "None"), asset: \(asset)"
        return myDescription
    }
    
}
