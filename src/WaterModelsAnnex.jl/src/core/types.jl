"Extended directed linear, relaxation-based models."
abstract type AbstractLRDXModel <: WM.AbstractLRDModel end
mutable struct LRDXWaterModel <: AbstractLRDXModel WM.@wm_fields end

"Extended directed linear, piecewise relaxation-based models."
abstract type AbstractPWLRDXModel <: WM.AbstractPWLRDModel end
mutable struct PWLRDXWaterModel <: AbstractPWLRDXModel WM.@wm_fields end