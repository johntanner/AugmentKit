//
//  Shaders.metal
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
//  Shaders that render anchors in 3D space.
//
// References --
// See: https://developer.apple.com/documentation/metal/advanced_techniques/lod_with_function_specialization#//apple_ref/doc/uid/TP40016233
// Sample Code: LODwithFunctionSpecialization
//
// See: https://developer.apple.com/videos/play/wwdc2017/610/
// Sample Code: ModelIO-from-MDLAsset-to-Game-Engine
//
// See MetalKitEssentialsUsingtheMetalKitViewTextureLoaderandModelIO
// https://developer.apple.com/videos/play/wwdc2015/607/
//

#include <metal_stdlib>
#include <simd/simd.h>

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "../ShaderTypes.h"
#import "../BRDFFunctions.h"
#import "../Common.h"

using namespace metal;

//
// Physically Based Shader
//
// This shader uses the following parameters following Disney's "principled" BDRF and
// Which are supported by ModelIO
// see: https://disney-animation.s3.amazonaws.com/library/s2012_pbs_disney_brdf_notes_v2.pdf
// • baseColor - the surface color, usually supplied by texture maps.
// • subsurface - controls diffuse shape using a subsurface approximation.
// • metallic - the metallic-ness (0 = dielectric, 1 = metallic). This is a linear blend between two different models. The metallic model has no diffuse component and also has a tinted incident specular, equal to the base color.
// • specular - incident specular amount. This is in lieu of an explicit index-of-refraction. 12
// • specularTint - a concession for artistic control that tints incident specular towards the base color. Grazing specular is still achromatic.
// • roughness - surface roughness, controls both diffuse and specular response.
// • anisotropic - degree of anisotropy. This controls the aspect ratio of the specular highlight. (0 = isotropic, 1 = maximally anisotropic).
// • sheen - an additional grazing component, primarily intended for cloth.
// • sheenTint - amount to tint sheen towards base color.
// • clearcoat - a second, special-purpose specular lobe.
// • clearcoatGloss - controls clearcoat glossiness (0 = a “satin” appearance, 1 = a “gloss” appearance).
//

// MARK: - Constants

constant bool has_base_color_map [[ function_constant(kFunctionConstantBaseColorMapIndex) ]];
constant bool has_normal_map [[ function_constant(kFunctionConstantNormalMapIndex) ]];
constant bool has_metallic_map [[ function_constant(kFunctionConstantMetallicMapIndex) ]];
constant bool has_roughness_map [[ function_constant(kFunctionConstantRoughnessMapIndex) ]];
constant bool has_ambient_occlusion_map [[ function_constant(kFunctionConstantAmbientOcclusionMapIndex) ]];
constant bool has_emission_map [[ function_constant(kFunctionConstantEmissionMapIndex) ]];
constant bool has_subsurface_map [[ function_constant(kFunctionConstantSubsurfaceMapIndex) ]];
constant bool has_specular_map [[ function_constant(kFunctionConstantSpecularMapIndex) ]];
constant bool has_specularTint_map [[ function_constant(kFunctionConstantSpecularTintMapIndex) ]];
constant bool has_anisotropic_map [[ function_constant(kFunctionConstantAnisotropicMapIndex) ]];
constant bool has_sheen_map [[ function_constant(kFunctionConstantSheenMapIndex) ]];
constant bool has_sheenTint_map [[ function_constant(kFunctionConstantSheenTintMapIndex) ]];
constant bool has_clearcoat_map [[ function_constant(kFunctionConstantClearcoatMapIndex) ]];
constant bool has_clearcoatGloss_map [[ function_constant(kFunctionConstantClearcoatGlossMapIndex) ]];
constant bool has_any_map = has_base_color_map || has_normal_map || has_metallic_map || has_roughness_map || has_ambient_occlusion_map || has_emission_map || has_subsurface_map || has_specular_map || has_specularTint_map || has_anisotropic_map || has_sheen_map || has_sheenTint_map || has_clearcoat_map || has_clearcoatGloss_map;

// MARK: - Structs

// MARK: Anchors Vertex In
// Per-vertex inputs fed by vertex buffer laid out with MTLVertexDescriptor in Metal API
struct Vertex {
    float3 position      [[attribute(kVertexAttributePosition)]];
    float2 texCoord      [[attribute(kVertexAttributeTexcoord)]];
    float3 normal        [[attribute(kVertexAttributeNormal)]];
    ushort4 jointIndices [[attribute(kVertexAttributeJointIndices)]];
    float4 jointWeights  [[attribute(kVertexAttributeJointWeights)]];
    float3 tangent       [[attribute(kVertexAttributeTangent)]];
//    float3 bitangent
//    float3 anisotropy,
//    float3 binormal,
//    float3 edgeCrease,
//    float3 occlusionValue,
//    float3 shadingBasisU,
//    float3 shadingBasisV,
//    float3 subdivisionStencil,
};

// MARK: Anchors Vertex Out / Fragment In
// Vertex shader outputs and per-fragmeht inputs.  Includes clip-space position and vertex outputs
//  interpolated by rasterizer and fed to each fragment genterated by clip-space primitives.
struct ColorInOut {
    float4 position [[position]];
    float3 eyePosition;
    float3 normal;
    float3 bitangent;
    float3 tangent;
    float2 texCoord [[ function_constant(has_any_map) ]];
    ushort iid;
};

// MARK: - Pipeline Functions

constexpr sampler linearSampler (address::repeat, min_filter::linear, mag_filter::linear, mip_filter::linear);
constexpr sampler nearestSampler(address::repeat, min_filter::linear, mag_filter::linear, mip_filter::none);
//constexpr sampler mipSampler(address::clamp_to_edge, min_filter::linear, mag_filter::linear, mip_filter::linear);
constexpr sampler reflectiveEnvironmentSampler(address::clamp_to_edge, min_filter::nearest, mag_filter::linear, mip_filter::none);

float3 computeNormalMap(ColorInOut in, texture2d<float> normalMapTexture) {
    float4 normalMap = float4((float4(normalMapTexture.sample(nearestSampler, float2(in.texCoord)).rgb, 0.0)));
    float3x3 TBN(in.tangent, in.bitangent, in.normal);
    return float3(normalize(TBN * normalMap.xyz));
}

float3 computeDiffuse(LightingParameters parameters) {
    
    // Pure metals have no diffuse component
    if (parameters.metalness == 1) {
        return float3(0);
    }
    
    // Method: 1
    
    // Diffuse fresnel - go from 1 at normal incidence to .5 at grazing
    // and mix in diffuse retro-reflection based on roughness
//    float Fd90 = 0.5 + 2.0 * sqr(parameters.lDoth) * sqr(parameters.roughness);
//    float Fd = mix(1.0, Fd90, parameters.fresnelNoL) + mix(1.0, Fd90, parameters.fresnelNoV);
//
//    // Based on Hanrahan-Krueger brdf approximation of isotropic bssrdf
//    // 1.25 scale is used to (roughly) preserve albedo
//    // Fss90 used to "flatten" retroreflection based on roughness
//    float Fss90 = sqr(parameters.lDoth) * sqr(parameters.roughness);
//    float Fss = mix(1.0, Fss90, parameters.fresnelNoL) * mix(1.0, Fss90, parameters.fresnelNoV);
//    // 1.25 scale is used to (roughly) preserve albedo
//    float ss = 1.25 * (Fss * (1.0 / (parameters.nDotl + parameters.nDotv) - 0.5) + 0.5);
//
//    float subsurface = 0.1; // TODO: parameters.subsurface
//    float3 diffuseOutput = ((1.0/M_PI_F) * mix(Fd, ss, subsurface) * parameters.baseColor.rgb) * (1.0 - parameters.metalness);
//    float3 light_color = float3(2.0 * M_PI_F * 0.3) * (parameters.nDotl + parameters.emissionColor - parameters.ambientOcclusion);
//    return parameters.directionalLightCol * diffuseOutput; // * light_color;
//
    // Method: 2
    float3 diffuseLightColor = float3(3) + parameters.ambientOcclusion;
    float3 diffuseColor = (parameters.baseColor.rgb / M_PI_F) * (1.0 - parameters.metalness);
    return diffuseColor * parameters.nDotl * diffuseLightColor;
    
}

float3 computeSpecular(LightingParameters parameters) {
    
    // Calculate BDRF
    // B-idirectional
    // R-eflectance
    // D-istribution
    // F-unction
    // BDRF is a function of light direction and view (camera/eye) direction
    // See: https://www.youtube.com/watch?v=j-A0mwsJRmk
    
    // Method 1

    //
    // Cook–Torrance formula
    // see: https://en.m.wikipedia.org/wiki/Specular_highlight#Cook–Torrance_model
    //

    // Roughness alpha
//    float specularRoughness = parameters.roughness;
//    specularRoughness = max(specularRoughness, 0.01f);
//    specularRoughness = pow(specularRoughness, 3.0f);
//
//    float aspect = sqrt(1.0 - parameters.anisotropic * 0.9);
//    float alphaAniso = sqr(specularRoughness);
//
//    float roughnessAlpha = sqr(specularRoughness * 0.5 + 0.5);
//    float roughnessAlphaX = max(0.0001, alphaAniso / aspect);
//    float roughnessAlphaY = max(0.0001, alphaAniso * aspect);
//
//    // Normal Distribution Function (NDF):
//    // The NDF, also known as the specular distribution, describes the distribution of microfacets for the surface.
//    // Determines the size and shape of the highlight.
//    float3 shadingBasisX = float3(1,0,0);
//    float3 shadingBasisY = float3(0,1,0);
//    float Ds = GTR2_aniso(parameters.nDoth, dot(parameters.halfVector, shadingBasisX), dot(parameters.halfVector, shadingBasisY), roughnessAlphaX, roughnessAlphaY);
//
//    // Fresnel Reflectance:
//    // The fraction of incoming light that is reflected as opposed to refracted from a flat surface at a given lighting angle.
//    // Fresnel Reflectance goes to 1 as the angle of incidence goes to 90º. The value of Fresnel Reflectance at 0º
//    // is the specular reflectance color.
//    float3 Cspec0 = parameters.specular * mix(float3(1.0), parameters.baseColorHueSat, parameters.specularTint);
//    float3 Fs = mix(Cspec0, float3(1), parameters.fresnelLoH);
//
//    // Geometric Shadowing:
//    // The geometric shadowing term describes the shadowing from the microfacets.
//    // This means ideally it should depend on roughness and the microfacet distribution.
//    // The following geometric shadowing models use Smith's method for their respective NDF.
//    // Smith breaks G into two components: light and view, and uses the same equation for both.
//    float Gs = smithG_GGX(parameters.nDotl, roughnessAlpha) * smithG_GGX(parameters.nDotv, roughnessAlpha);
//
//    float3 specularBDRF = (Ds * Gs * Fs) / (4 * parameters.nDotl * parameters.nDotv);
//    float3 specularOutput = specularBDRF * parameters.reflectedColor * parameters.directionalLightCol * mix(float3(1.0f), parameters.baseColor.rgb, parameters.metalness) * parameters.nDoth;
//    return specularOutput;
    
    // Method 2
    
    float specularRoughness = parameters.roughness * (1.0 - parameters.metalness) + parameters.metalness;

    // Normal Distribution Function (NDF):
    // The NDF, also known as the specular distribution, describes the distribution of microfacets for the surface.
    // Determines the size and shape of the highlight.
    float Ds = TrowbridgeReitzNDF(parameters.nDoth, specularRoughness);

    // Fresnel Reflectance:
    // The fraction of incoming light that is reflected as opposed to refracted from a flat surface at a given lighting angle.
    // Fresnel Reflectance goes to 1 as the angle of incidence goes to 90º. The value of Fresnel Reflectance at 0º
    // is the specular reflectance color.
    float3 Cspec0 = parameters.specular * mix(float3(1.0), parameters.baseColorHueSat, parameters.specularTint);
    float3 Fs = mix(Cspec0, float3(1), parameters.fresnelLoH);
    
    // Geometric Shadowing:
    // The geometric shadowing term describes the shadowing from the microfacets.
    // This means ideally it should depend on roughness and the microfacet distribution.
    // The following geometric shadowing models use Smith's method for their respective NDF.
    // Smith breaks G into two components: light and view, and uses the same equation for both.
    float roughnessAlpha = sqr(specularRoughness * 0.5 + 0.5);
    float Gs = smithG_GGX(parameters.nDotl, roughnessAlpha) * smithG_GGX(parameters.nDotv, roughnessAlpha);

    float3 specularOutput = (Ds * Gs * Fs * parameters.reflectedColor) * (1.0 + parameters.metalness * parameters.baseColor.rgb) + parameters.reflectedColor * parameters.metalness * parameters.baseColor.rgb;
    return specularOutput;
    
    // Method 3
    
//    float a = parameters.roughness * parameters.roughness;
//    float3 f0 = 0.16 * sqr(parameters.specular) * (1.0 - parameters.metalness) + parameters.baseColor.rgb * parameters.metalness;
//
//    float D = specularD(parameters.nDoth, a);
//    float3 F = specularF(parameters.lDoth, f0);
//    float V = specularG(parameters.nDotv, parameters.nDotl, a);
//
//    // specular BRDF
//    float3 Fr = (D * V) * F;
//    return Fr;
    
}

float3 computeClearcoat(LightingParameters parameters) {
    
    // Method 1
    
    // For Dielectics (non-metals) the Fresnel for 0º typically ranges from 0.02 (water) to 0.1 (diamond) but for
    // the sake of simplicity, it is common to set this value as a constant of 0.04 (plastic/glass) for all materials.
    float Fr = mix(0.1, 0.04, parameters.fresnelLoH);
    float Dr = TrowbridgeReitzNDF(parameters.nDoth, mix(.6, 0.001, parameters.clearcoatGloss));
    float clearcoatRoughness = sqr(parameters.roughness * 0.5 + 0.5);
    float Gr = smithG_GGX(parameters.nDotl, clearcoatRoughness) * smithG_GGX(parameters.nDotv, clearcoatRoughness);
    
    float3 clearcoatOutput = parameters.clearcoat * Gr * Fr * Dr * parameters.directionalLightCol;
    return clearcoatOutput;
    
    // Method 2
    
//    // remapping and linearization of clear coat roughness
//    float clearCoatRoughness = mix(0.089, 0.6, parameters.clearcoatGloss);
//    float clearCoatLinearRoughness = sqr(clearCoatRoughness);
//
//    // clear coat BRDF
//    float  Dc = specularD(clearCoatLinearRoughness, parameters.nDoth);
//    float  Vc = V_Kelemen(parameters.lDoth);
//    float  Fc = specularF(0.04, parameters.lDoth) * parameters.clearcoat; // clear coat strength
//    float Frc = (Dc * Vc) * Fc;
//
//    // account for energy loss in the base layer
//    return parameters.directionalLightCol * ((Fd + Fr * (1.0 - Fc)) * (1.0 - Fc) + Frc);
    
    
}

float3 computeSheen(LightingParameters parameters) {
    
    float3 Csheen = mix(float3(1.0), parameters.baseColorHueSat, parameters.sheenTint);
    float3 Fsheen = Csheen * parameters.fresnelNoV * parameters.sheen;
    
//    float3 light_color = float3(2.0 * M_PI_F * 0.3) * (parameters.nDotl + parameters.emissionColor - parameters.ambientOcclusion);
    float3 sheenOutput = Fsheen; // * light_color;
    return sheenOutput;
    
}

// all input colors must be linear, not SRGB.
float4 illuminate(LightingParameters parameters) {
    
    // DIFFUSE
    float3 diffuseOut = computeDiffuse(parameters);
    
    // AMBIENCE
//    const float environmentContribution = 1;
//    float3 ambienceOutput = parameters.ambientLightCol * environmentContribution * parameters.ambientOcclusion;
    
    // CLEARCOAT
//    float3 clearcoatOut = computeClearcoat(parameters);
    
    // SPECULAR
    float3 specularOut = computeSpecular(parameters);
    
    // SHEEN
//    float3 sheenOut = computeSheen(parameters);
    
    // REFLECTED ENVIRONMENT
//    float3 reflectedEnvironment = parameters.reflectedColor * parameters.metalness;
    
//    return float4(diffuseOut + ambienceOutput + clearcoatOut + specularOut + sheenOut + reflectedEnvironment, 1);
    return float4(diffuseOut + specularOut + parameters.emissionColor, 1);
}

LightingParameters calculateParameters(ColorInOut in,
                                       constant SharedUniforms & sharedUniforms,
                                       constant MaterialUniforms & materialUniforms,
                                       constant EnvironmentUniforms *environmentUniforms,
                                       texture2d<float> baseColorMap [[ function_constant(has_base_color_map) ]],
                                       texture2d<float> normalMap [[ function_constant(has_normal_map) ]],
                                       texture2d<float> metallicMap [[ function_constant(has_metallic_map) ]],
                                       texture2d<float> roughnessMap [[ function_constant(has_roughness_map) ]],
                                       texture2d<float> ambientOcclusionMap [[ function_constant(has_ambient_occlusion_map) ]],
                                       texture2d<float> emissionMap [[ function_constant(has_emission_map) ]],
                                       texture2d<float> subsurfaceMap [[ function_constant(has_subsurface_map) ]],
                                       texture2d<float> specularMap [[ function_constant(has_specular_map) ]],
                                       texture2d<float> specularTintMap [[ function_constant(has_specularTint_map) ]],
                                       texture2d<float> anisotropicMap [[ function_constant(has_anisotropic_map) ]],
                                       texture2d<float> sheenMap [[ function_constant(has_sheen_map) ]],
                                       texture2d<float> sheenTintMap [[ function_constant(has_sheenTint_map) ]],
                                       texture2d<float> clearcoatMap [[ function_constant(has_clearcoat_map) ]],
                                       texture2d<float> clearcoatGlossMap [[ function_constant(has_clearcoatGloss_map) ]],
                                       texturecube<float> environmentCubemap [[ texture(kTextureIndexEnvironmentMap) ]]
                                       ) {
    LightingParameters parameters;
    
    float4 baseColor = has_base_color_map ? srgbToLinear(baseColorMap.sample(linearSampler, in.texCoord.xy)) : materialUniforms.baseColor;
    parameters.baseColor = float4(baseColor.xyz, baseColor.w * materialUniforms.opacity);
    
    parameters.baseColorLuminance = 0.3 * parameters.baseColor.x + 0.6 * parameters.baseColor.y + 0.1 * parameters.baseColor.z; // approximation of luminanc
    parameters.baseColorHueSat = parameters.baseColorLuminance > 0.0 ? parameters.baseColor.rgb / parameters.baseColorLuminance : float3(1); // remove luminance
    
    parameters.subsurface = has_subsurface_map ? subsurfaceMap.sample(linearSampler, in.texCoord.xy).x : materialUniforms.subsurface;
    
    parameters.specular = has_specular_map ? specularMap.sample(linearSampler, in.texCoord.xy).x : materialUniforms.specular;
    
    parameters.specularTint = has_specularTint_map ? specularTintMap.sample(linearSampler, in.texCoord.xy).x : materialUniforms.specularTint;
    
    parameters.sheen = has_sheen_map ? sheenMap.sample(linearSampler, in.texCoord.xy).x : materialUniforms.sheen;
    
    parameters.sheenTint = has_sheenTint_map ? sheenTintMap.sample(linearSampler, in.texCoord.xy).x : materialUniforms.sheenTint;
    
    parameters.anisotropic = has_anisotropic_map ? anisotropicMap.sample(linearSampler, in.texCoord.xy).x : materialUniforms.anisotropic;
    
    parameters.clearcoat = has_clearcoat_map ? clearcoatMap.sample(linearSampler, in.texCoord.xy).x : materialUniforms.clearcoat;
    
    parameters.clearcoatGloss = has_clearcoatGloss_map ? clearcoatGlossMap.sample(linearSampler, in.texCoord.xy).x : materialUniforms.clearcoatGloss;
    
    parameters.normal = has_normal_map ? computeNormalMap(in, normalMap) : float3(in.normal);
    
    // TODO: ??? - not sure if this is correct. float3(in.eyePosition) or -float3(in.eyePosition) ?
    parameters.viewDir = float3(in.eyePosition);
    parameters.reflectedVector = reflect(-parameters.viewDir, parameters.normal);
//    parameters.reflectedColor = float3(0, 0, 0); //
    parameters.reflectedColor = (environmentUniforms[in.iid].hasEnvironmentMap == 1) ? environmentCubemap.sample(reflectiveEnvironmentSampler, parameters.reflectedVector).xyz : float3(0, 0, 0);
    
    parameters.roughness = has_roughness_map ? max(roughnessMap.sample(linearSampler, in.texCoord.xy).x, 0.001f) : materialUniforms.roughness;
    parameters.metalness = has_metallic_map ? metallicMap.sample(linearSampler, in.texCoord.xy).x : materialUniforms.metalness;
    
    parameters.diffuseColor = (1.0 - parameters.metalness) * baseColor.rgb;
    
//    uint8_t mipLevel = parameters.roughness * emissionMap.get_num_mip_levels();
//    parameters.emissionColor = has_emission_map ? emissionMap.sample(mipSampler, parameters.reflectedVector, level(mipLevel)).xyz : materialUniforms.emissionColor.xyz;
    parameters.emissionColor = has_emission_map ? emissionMap.sample(linearSampler, in.texCoord.xy).xyz : materialUniforms.emissionColor;
    parameters.ambientOcclusion = has_ambient_occlusion_map ? max(srgbToLinear(ambientOcclusionMap.sample(linearSampler, in.texCoord.xy)).x, 0.001f) : materialUniforms.ambientOcclusion;
    
    parameters.directionalLightCol = environmentUniforms[in.iid].directionalLightColor;
    parameters.ambientLightCol = environmentUniforms[in.iid].ambientLightColor;
    parameters.lightDirection = -environmentUniforms[in.iid].directionalLightDirection;
    
    // Light falls off based on how closely aligned the surface normal is to the light direction.
    // This is the dot product of the light direction vector and vertex normal.
    // The smaller the angle between those two vectors, the higher this value,
    // and the stronger the diffuse lighting effect should be.
    parameters.nDotl = max(0.001f,saturate(dot(parameters.normal, parameters.lightDirection)));
    
    // Calculate the halfway vector between the light direction and the direction they eye is looking
    parameters.halfVector = normalize(parameters.lightDirection + parameters.viewDir);
    
    parameters.nDoth = max(0.001f,saturate(dot(parameters.normal, parameters.halfVector)));
    parameters.nDotv = max(0.001f,saturate(dot(parameters.normal, parameters.viewDir)));
    parameters.lDoth = max(0.001f,saturate(dot(parameters.lightDirection, parameters.halfVector)));
    
    parameters.fresnelNoL = Fresnel(0.04, 1.0, parameters.nDotl);
    parameters.fresnelNoV = Fresnel(0.04, 1.0, parameters.nDotv);
    parameters.fresnelLoH = Fresnel(0.04, 1.0, parameters.lDoth);
    
    return parameters;
    
}

// MARK: - Anchor Shaders

// MARK: Anchor vertex function
vertex ColorInOut anchorGeometryVertexTransform(Vertex in [[stage_in]],
                                                constant SharedUniforms &sharedUniforms [[ buffer(kBufferIndexSharedUniforms) ]],
                                                constant AnchorInstanceUniforms *anchorInstanceUniforms [[ buffer(kBufferIndexAnchorInstanceUniforms) ]],
                                                constant AnchorEffectsUniforms *anchorEffectsUniforms [[ buffer(kBufferIndexAnchorEffectsUniforms) ]],
                                                uint vid [[vertex_id]],
                                                ushort iid [[instance_id]]) {
    ColorInOut out;
    
    // Make position a float4 to perform 4x4 matrix math on it
    float4 position = float4(in.position, 1.0);
    
    // Get the anchor model's orientation in world space
    float4x4 modelMatrix = anchorInstanceUniforms[iid].modelMatrix;
    float3x3 normalMatrix = anchorInstanceUniforms[iid].normalMatrix;
    
    // Apply effects that affect geometry
    float4x4 scaleMatrix = float4x4(anchorEffectsUniforms[iid].scale);
    scaleMatrix[3][3] = 1;
    modelMatrix = modelMatrix * scaleMatrix;
    
    // Transform the model's orientation from world space to camera space.
    float4x4 modelViewMatrix = sharedUniforms.viewMatrix * modelMatrix;
    
    // Calculate the position of our vertex in clip space and output for clipping and rasterization
    out.position = sharedUniforms.projectionMatrix * modelViewMatrix * position;
    
    // Calculate the positon of our vertex in eye space
    out.eyePosition = float3((modelViewMatrix * position).xyz);
    
    // Rotate our normals to world coordinates
    out.normal = normalMatrix * in.normal;
    out.tangent = normalMatrix * in.tangent;
    out.bitangent = normalMatrix * cross(in.normal, in.tangent);
    
    // Pass along the texture coordinate of our vertex such which we'll use to sample from texture's
    //   in our fragment function, if we need it
    if (has_any_map) {
        out.texCoord = float2(in.texCoord.x, 1.0f - in.texCoord.y);
    }
    
    out.iid = iid;
    
    return out;
}

// MARK: Anchor vertex function with skinning
vertex ColorInOut anchorGeometryVertexTransformSkinned(Vertex in [[stage_in]],
                                                       constant SharedUniforms &sharedUniforms [[ buffer(kBufferIndexSharedUniforms) ]],
                                                       constant float4x4 *palette [[buffer(kBufferIndexMeshPalettes)]],
                                                       constant int &paletteStartIndex [[buffer(kBufferIndexMeshPaletteIndex)]],
                                                       constant int &paletteSize [[buffer(kBufferIndexMeshPaletteSize)]],
                                                       constant AnchorInstanceUniforms *anchorInstanceUniforms [[ buffer(kBufferIndexAnchorInstanceUniforms) ]],
                                                       constant AnchorEffectsUniforms *anchorEffectsUniforms [[ buffer(kBufferIndexAnchorEffectsUniforms) ]],
                                                       uint vid [[vertex_id]],
                                                       ushort iid [[instance_id]]) {
    
    ColorInOut out;
    
    // Make position a float4 to perform 4x4 matrix math on it
    float4 position = float4(in.position, 1.0f);
    
    // Get the anchor model's orientation in world space
    float4x4 modelMatrix = anchorInstanceUniforms[iid].modelMatrix;
    float3x3 normalMatrix = anchorInstanceUniforms[iid].normalMatrix;
    
    // Apply effects that affect geometry
    float4x4 scaleMatrix = float4x4(anchorEffectsUniforms[iid].scale);
    scaleMatrix[3][3] = 1;
    modelMatrix = modelMatrix * scaleMatrix;
    
    // Transform the model's orientation from world space to camera space.
    float4x4 modelViewMatrix = sharedUniforms.viewMatrix * modelMatrix;
    
    ushort4 jointIndex = in.jointIndices + paletteStartIndex + iid * paletteSize;
    float4 weights = in.jointWeights;
    
    float4 skinnedPosition = weights[0] * (palette[jointIndex[0]] * position) +
        weights[1] * (palette[jointIndex[1]] * position) +
        weights[2] * (palette[jointIndex[2]] * position) +
        weights[3] * (palette[jointIndex[3]] * position);
    
    float4 modelNormal = float4(in.normal, 0.0f);
    float4 skinnedNormal = weights[0] * (palette[jointIndex[0]] * modelNormal) +
        weights[1] * (palette[jointIndex[1]] * modelNormal) +
        weights[2] * (palette[jointIndex[2]] * modelNormal) +
        weights[3] * (palette[jointIndex[3]] * modelNormal);
    
    float4 modelTangent = float4(in.tangent, 0.0f);
    float4 skinnedTangent = weights[0] * (palette[jointIndex[0]] * modelTangent) +
        weights[1] * (palette[jointIndex[1]] * modelTangent) +
        weights[2] * (palette[jointIndex[2]] * modelTangent) +
        weights[3] * (palette[jointIndex[3]] * modelTangent);
    
    // Calculate the position of our vertex in clip space and output for clipping and rasterization
    out.position = sharedUniforms.projectionMatrix * modelViewMatrix * skinnedPosition;
    
    // Calculate the positon of our vertex in eye space
    out.eyePosition = float3((modelViewMatrix * skinnedPosition).xyz);
    
    // Rotate our normals to world coordinates
    out.normal = normalMatrix * skinnedNormal.xyz;
    out.tangent = normalMatrix * skinnedTangent.xyz;
    out.bitangent = normalMatrix * cross(skinnedNormal.xyz, skinnedTangent.xyz);
    
    // Pass along the texture coordinate of our vertex such which we'll use to sample from texture's
    //   in our fragment function, if we need it
    if (has_any_map) {
        out.texCoord = float2(in.texCoord.x, 1.0f - in.texCoord.y);
    }
    
    out.iid = iid;
    
    return out;
    
}

// MARK: Anchor fragment function with materials

fragment float4 anchorGeometryFragmentLighting(ColorInOut in [[stage_in]],
                                               constant SharedUniforms &sharedUniforms [[ buffer(kBufferIndexSharedUniforms) ]],
                                               constant MaterialUniforms &materialUniforms [[ buffer(kBufferIndexMaterialUniforms) ]],
                                               constant EnvironmentUniforms *environmentUniforms [[ buffer(kBufferIndexEnvironmentUniforms) ]],
                                               constant AnchorEffectsUniforms *anchorEffectsUniforms [[ buffer(kBufferIndexAnchorEffectsUniforms) ]],
                                               texture2d<float> baseColorMap [[ texture(kTextureIndexColor), function_constant(has_base_color_map) ]],
                                               texture2d<float> normalMap    [[ texture(kTextureIndexNormal), function_constant(has_normal_map) ]],
                                               texture2d<float> metallicMap  [[ texture(kTextureIndexMetallic), function_constant(has_metallic_map) ]],
                                               texture2d<float> roughnessMap  [[ texture(kTextureIndexRoughness), function_constant(has_roughness_map) ]],
                                               texture2d<float> ambientOcclusionMap  [[ texture(kTextureIndexAmbientOcclusion), function_constant(has_ambient_occlusion_map) ]],
                                               texture2d<float> emissionMap [[texture(kTextureIndexEmissionMap), function_constant(has_emission_map)]],
                                               texture2d<float> subsurfaceMap [[texture(kTextureIndexSubsurfaceMap), function_constant(has_subsurface_map)]],
                                               texture2d<float> specularMap [[  texture(kTextureIndexSpecularMap), function_constant(has_specular_map) ]],
                                               texture2d<float> specularTintMap [[  texture(kTextureIndexSpecularTintMap), function_constant(has_specularTint_map) ]],
                                               texture2d<float> anisotropicMap [[  texture(kTextureIndexAnisotropicMap), function_constant(has_anisotropic_map) ]],
                                               texture2d<float> sheenMap [[  texture(kTextureIndexSheenMap), function_constant(has_sheen_map) ]],
                                               texture2d<float> sheenTintMap [[  texture(kTextureIndexSheenTintMap), function_constant(has_sheenTint_map) ]],
                                               texture2d<float> clearcoatMap [[  texture(kTextureIndexClearcoatMap), function_constant(has_clearcoat_map) ]],
                                               texture2d<float> clearcoatGlossMap [[  texture(kTextureIndexClearcoatGlossMap), function_constant(has_clearcoatGloss_map) ]],
                                               texturecube<float> environmentCubemap [[  texture(kTextureIndexEnvironmentMap) ]]
                                               ) {
    
    float4 final_color = float4(0);
    ushort iid = in.iid;
    
    LightingParameters parameters = calculateParameters(in,
                                                        sharedUniforms,
                                                        materialUniforms,
                                                        environmentUniforms,
                                                        baseColorMap,
                                                        normalMap,
                                                        metallicMap,
                                                        roughnessMap,
                                                        ambientOcclusionMap,
                                                        emissionMap,
                                                        subsurfaceMap,
                                                        specularMap,
                                                        specularTintMap,
                                                        anisotropicMap,
                                                        sheenMap,
                                                        sheenTintMap,
                                                        clearcoatMap,
                                                        clearcoatGlossMap,
                                                        environmentCubemap);
    
    
    // FIXME: discard_fragment may have performance implications.
    // see: http://metalbyexample.com/translucency-and-transparency/
    if ( parameters.baseColor.w <= 0.01f ) {
        discard_fragment();
    }

//    float4 intermediate_color =  illuminate(parameters);
    float4 intermediate_color =  float4(parameters.baseColor * illuminate(parameters));
    
    // Apply effects
    final_color = float4(intermediate_color.rgb * anchorEffectsUniforms[iid].tint, intermediate_color.a * anchorEffectsUniforms[iid].alpha);
    
    return final_color;
    
}

// MARK: Anchor fragment shader that uses the base color only

fragment float4 anchorGeometryFragmentLightingSimple(ColorInOut in [[stage_in]],
                                               constant SharedUniforms &sharedUniforms [[ buffer(kBufferIndexSharedUniforms) ]],
                                               constant MaterialUniforms &materialUniforms [[ buffer(kBufferIndexMaterialUniforms) ]],
                                               constant EnvironmentUniforms *environmentUniforms [[ buffer(kBufferIndexEnvironmentUniforms) ]],
                                               constant AnchorEffectsUniforms *anchorEffectsUniforms [[ buffer(kBufferIndexAnchorEffectsUniforms) ]],
                                               texture2d<float> baseColorMap [[ texture(kTextureIndexColor), function_constant(has_base_color_map) ]],
                                               texture2d<float> normalMap    [[ texture(kTextureIndexNormal), function_constant(has_normal_map) ]],
                                               texture2d<float> metallicMap  [[ texture(kTextureIndexMetallic), function_constant(has_metallic_map) ]],
                                               texture2d<float> roughnessMap  [[ texture(kTextureIndexRoughness), function_constant(has_roughness_map) ]],
                                               texture2d<float> ambientOcclusionMap  [[ texture(kTextureIndexAmbientOcclusion), function_constant(has_ambient_occlusion_map) ]],
                                               texture2d<float> emissionMap [[texture(kTextureIndexEmissionMap), function_constant(has_emission_map)]],
                                               texture2d<float> subsurfaceMap [[texture(kTextureIndexSubsurfaceMap), function_constant(has_subsurface_map)]],
                                               texture2d<float> specularMap [[  texture(kTextureIndexSpecularMap), function_constant(has_specular_map) ]],
                                               texture2d<float> specularTintMap [[  texture(kTextureIndexSpecularTintMap), function_constant(has_specularTint_map) ]],
                                               texture2d<float> anisotropicMap [[  texture(kTextureIndexAnisotropicMap), function_constant(has_anisotropic_map) ]],
                                               texture2d<float> sheenMap [[  texture(kTextureIndexSheenMap), function_constant(has_sheen_map) ]],
                                               texture2d<float> sheenTintMap [[  texture(kTextureIndexSheenTintMap), function_constant(has_sheenTint_map) ]],
                                               texture2d<float> clearcoatMap [[  texture(kTextureIndexClearcoatMap), function_constant(has_clearcoat_map) ]],
                                               texture2d<float> clearcoatGlossMap [[  texture(kTextureIndexClearcoatGlossMap), function_constant(has_clearcoatGloss_map) ]],
                                               texturecube<float> environmentCubemap [[  texture(kTextureIndexEnvironmentMap) ]]
                                               ) {
    
    float4 final_color = float4(0);
    ushort iid = in.iid;
    
    float4 baseColor = has_base_color_map ? srgbToLinear(baseColorMap.sample(linearSampler, in.texCoord.xy)) : materialUniforms.baseColor;
    
    // FIXME: discard_fragment may have performance implications.
    // see: http://metalbyexample.com/translucency-and-transparency/
    if ( baseColor.w <= 0.01f ) {
        discard_fragment();
    }
    
    // Apply effects
    final_color = float4(baseColor.rgb * anchorEffectsUniforms[iid].tint, baseColor.a * anchorEffectsUniforms[iid].alpha);
    
    return final_color;
    
}

