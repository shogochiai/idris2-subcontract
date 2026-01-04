||| VaultPJ Main Entry Point
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
import Main.Functions.Deposit
import Main.Functions.Withdraw
import Main.Functions.Admin

export
main : IO ()
main = dispatch
  [ -- Deposit
    entry depositEntry
  , entry depositOfEntry
    -- Withdraw
  , entry withdrawEntry
  , entry withdrawAllEntry
    -- Admin
  , entry pauseEntry
  , entry unpauseEntry
  , entry ownerEntry
  , entry totalDepositsEntry
  ]
