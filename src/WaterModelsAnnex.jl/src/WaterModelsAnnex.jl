module WaterModelsAnnex

import Gurobi
import LinearAlgebra
import PolyhedralRelaxations
import WaterModels

const WM = WaterModels
const JuMP = WM.JuMP
const MOI = WM.JuMP.MOI
const MOIU = WM.JuMP.MOI.Utilities
const LOGGER = WM.Memento.getlogger(WM)

# Register the module level logger at runtime so that it can be accessed via
# `getlogger(WaterModelsAnnex)` NOTE: If this line is not included then the
# precompiled `WaterModelsAnnex.LOGGER` won't be registered at runtime.
__init__() = WM.Memento.register(LOGGER)

"Suppresses information and warning messages output by WaterModels. For fine-grained control use the Memento package."
function silence()
    WM.Memento.info(LOGGER, "Suppressing information and warning messages for the rest of this session  Use the Memento package for fine-grained control of logging.")
    WM.Memento.setlevel!(Memento.getlogger(WM._IM), "error")
    WM.Memento.setlevel!(Memento.getlogger(WM), "error")
end

include("core/types.jl")
include("core/constraint_template.jl")
include("core/control_setting.jl")
include("core/simulation_result.jl")

include("form/lrdx.jl")
include("form/pwlrdx.jl")

include("prob/wf.jl")

include("alg/todini_pilati.jl")
include("alg/owf_lazy_cut_callback.jl")
include("alg/solve_owf.jl")

include("core/export.jl")

end
