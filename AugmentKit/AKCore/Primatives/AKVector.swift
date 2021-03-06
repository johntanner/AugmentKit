//
//  AKVector.swift
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

/**
 A three dimensional vector object
 */
public struct AKVector: Equatable {
    /**
     The X component
     */
    public var x: Double = 0
    /**
     The Y component
     */
    public var y: Double = 0
    /**
     The Z component
     */
    public var z: Double = 0
    /**
     Normalize the vector
     */
    mutating func normalize() {
        let newVecor = simd.normalize(double3(x, y, z))
        x = newVecor.x
        y = newVecor.y
        z = newVecor.z
    }
    /**
     Createds a normalized vector from the current vector
     */
    func normalized() -> AKVector {
        let newVecor = simd.normalize(double3(x, y, z))
        return AKVector(x: newVecor.x, y: newVecor.y, z: newVecor.z)
    }
}
