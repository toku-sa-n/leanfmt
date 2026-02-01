import Lean
import Lean.Parser
import Lean.PrettyPrinter

namespace Leanfmt.Debug
open Lean (logInfo)
elab "#tree" s:term : command => do
  logInfo (repr s.raw)
elab "#tree" s:command : command => do
  logInfo (repr s.raw)
end Leanfmt.Debug
