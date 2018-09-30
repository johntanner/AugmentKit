//
//  AKTarget.swift
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

import Foundation
import simd

// MARK: - AKTarget

/**
 An `AKTarget` is a geometrical object which is positioned at the intersection of a vector and another `AKGeometricEntity`. The vector is relative to a position.
 - Example:
 An `AKTarget` might be the red dot of a laser pointer. Where the laser intersects a screen is be where the geometry of the dot is rendered. The location of the intersection is determined by the vector representing the direction the laser pointer is pointed as well as the postion of the laser pointer itself in the world.
 */
public protocol AKTarget: AKGeometricEntity {
    /**
     A direction vector relative to it's position and can be a unit vector
     */
    var vectorDirection: AKVector { get }
    /**
     A relative position
     */
    var position: AKRelativePosition { get }
    /**
     Set the identifier for this instance
     - Parameters:
        - _: A UUID
     */
    func setIdentifier(_ identifier: UUID)
}
