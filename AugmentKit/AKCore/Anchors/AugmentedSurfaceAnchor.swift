//
//  AugmentedSurfaceAnchor.swift
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
//
//  A generic implementation of AKAugmentedSurfaceAnchor that renders a MDLTexture
//  on a simple plane with a given extent
//

import ARKit
import Foundation
import MetalKit
import simd

public class AugmentedSurfaceAnchor: AKAugmentedSurfaceAnchor {
    
    public static var type: String {
        return "AugmentedSurface"
    }
    public var worldLocation: AKWorldLocation
    public var asset: MDLAsset
    public var identifier: UUID?
    public var effects: [AnyEffect<Any>]?
    public var arAnchor: ARAnchor?
    
    public init(withTexture texture: MDLTexture, extent: vector_float3, at location: AKWorldLocation, withAllocator metalAllocator: MTKMeshBufferAllocator? = nil) {
        
        let mesh = MDLMesh(planeWithExtent: extent, segments: vector2(1, 1), geometryType: .triangles, allocator: metalAllocator)
        let scatteringFunction = MDLScatteringFunction()
        let material = MDLMaterial(name: "baseMaterial", scatteringFunction: scatteringFunction)
        let textureSampler = MDLTextureSampler()
        textureSampler.texture = texture
        let property = MDLMaterialProperty(name: "baseColor", semantic: MDLMaterialSemantic.baseColor, textureSampler: textureSampler)
        material.setProperty(property)
        
        for submesh in mesh.submeshes!  {
            if let submesh = submesh as? MDLSubmesh {
                submesh.material = material
            }
        }
        let asset = MDLAsset(bufferAllocator: metalAllocator)
        asset.add(mesh)
        
        self.asset = asset
        self.worldLocation = location
        
    }
    
    public func setIdentifier(_ identifier: UUID) {
        self.identifier = identifier
    }
    
    public func setARAnchor(_ arAnchor: ARAnchor) {
        self.arAnchor = arAnchor
        if identifier == nil {
            identifier = arAnchor.identifier
        }
        worldLocation.transform = arAnchor.transform
    }
    
}

extension AugmentedSurfaceAnchor: CustomDebugStringConvertible, CustomStringConvertible {
    
    public var description: String {
        return debugDescription
    }
    
    public var debugDescription: String {
        let myDescription = "<AugmentedSurfaceAnchor: \(Unmanaged.passUnretained(self).toOpaque())> worldLocation: \(worldLocation), identifier:\(identifier?.uuidString ?? "None"), effects: \(effects?.debugDescription ?? "None"), arAnchor: \(arAnchor?.debugDescription ?? "None"), asset: \(asset)"
        return myDescription
    }
    
}
