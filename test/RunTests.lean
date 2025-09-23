import Lean

def main : IO Unit := do
  let exitCode ← IO.Process.spawn { cmd := "scripts/run-tests.sh" } >>= (·.wait)
  if exitCode != 0 then IO.Process.exit exitCode.toUInt8
