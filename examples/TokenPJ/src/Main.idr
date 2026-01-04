||| TokenPJ Main Entry Point
|||
||| NOTE: This is IMPLEMENTATION code, not a standalone executable.
||| Users interact with a PROXY contract that DELEGATECALLs here.
|||
||| Deployment flow:
|||   1. Deploy this implementation → get implAddr
|||   2. Deploy Dictionary, register implAddr for each selector
|||   3. Deploy Proxy pointing to Dictionary
|||   4. Users send tx to PROXY address (not this contract)
|||
||| See: examples/README.md for architecture diagram
module Main

import Subcontract.Core.Entry

import Main.Functions.Transfer
import Main.Functions.Approve
import Main.Functions.Mint
import Main.Functions.View

-- =============================================================================
-- Main Dispatcher
-- =============================================================================

||| Token implementation entry point
||| Called via DELEGATECALL from Proxy
export
main : IO ()
main = dispatch
  [ -- Transfer
    entry transferEntry
    -- Approve
  , entry approveEntry
  , entry allowanceEntry
    -- Mint
  , entry mintEntry
    -- View
  , entry totalSupplyEntry
  , entry balanceOfEntry
  , entry ownerEntry
  ]
