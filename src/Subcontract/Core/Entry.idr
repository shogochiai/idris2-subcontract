||| Subcontract Core: Type-Safe Entry Points
|||
||| Provides type-level binding between function signatures and handlers.
||| Eliminates selector dispatch boilerplate while maintaining type safety.
|||
||| Example:
|||   addMemberEntry : Entry addMemberSig
|||   addMemberEntry = MkEntry addMemberSel $ do
|||     (addr, meta) <- runDecoder (decodeAddress <&> decodeBytes32)
|||     idx <- addMemberImpl (addrValue addr) (bytes32Value meta)
|||     returnUint idx
|||
module Subcontract.Core.Entry

import public Subcontract.Core.ABI.Sig
import public Subcontract.Core.ABI.Decoder
import EVM.Storage.ERC7201

-- =============================================================================
-- EVM Primitives for Return/Revert
-- =============================================================================

%foreign "evm:return"
prim__return : Integer -> Integer -> PrimIO ()

%foreign "evm:revert"
prim__revert : Integer -> Integer -> PrimIO ()

export
evmReturn : Integer -> Integer -> IO ()
evmReturn off len = primIO (prim__return off len)

export
evmRevert : Integer -> Integer -> IO ()
evmRevert off len = primIO (prim__revert off len)

-- =============================================================================
-- Return Value Helpers
-- =============================================================================

||| Return a single uint256
export
returnUint : Integer -> IO ()
returnUint val = do
  mstore 0 val
  evmReturn 0 32

||| Return a boolean
export
returnBool : Bool -> IO ()
returnBool b = returnUint (if b then 1 else 0)

||| Return two uint256 values
export
returnUint2 : Integer -> Integer -> IO ()
returnUint2 v1 v2 = do
  mstore 0 v1
  mstore 32 v2
  evmReturn 0 64

-- =============================================================================
-- Entry Point Type
-- =============================================================================

||| An entry point bound to a specific signature
||| The phantom type `sig` ensures the selector matches the signature
public export
record Entry (sig : Sig) where
  constructor MkEntry
  selector : Sel sig
  handler : IO ()

-- =============================================================================
-- Selector Extraction
-- =============================================================================

||| Extract function selector from calldata (first 4 bytes, right-aligned)
export
getSelector : IO Integer
getSelector = do
  data_ <- calldataload 0
  pure (data_ `div` 0x100000000000000000000000000000000000000000000000000000000)

-- =============================================================================
-- Dispatch
-- =============================================================================

||| Existential wrapper for entries with different signatures
public export
data SomeEntry : Type where
  MkSomeEntry : {sig : Sig} -> Entry sig -> SomeEntry

||| Get selector value from existential entry
export
someEntrySelector : SomeEntry -> Integer
someEntrySelector (MkSomeEntry e) = selValue e.selector

||| Get handler from existential entry
export
someEntryHandler : SomeEntry -> IO ()
someEntryHandler (MkSomeEntry e) = e.handler

||| Dispatch based on selector
||| Finds matching entry and executes its handler
export
dispatch : List SomeEntry -> IO ()
dispatch entries = do
  sel <- getSelector
  case find (\e => someEntrySelector e == sel) entries of
    Nothing => evmRevert 0 0
    Just entry => someEntryHandler entry

-- =============================================================================
-- Convenience: Wrap entry for dispatch
-- =============================================================================

||| Convert typed entry to existential for dispatch list
export
entry : {sig : Sig} -> Entry sig -> SomeEntry
entry = MkSomeEntry

-- =============================================================================
-- Debug: List all registered selectors
-- =============================================================================

||| Get list of all registered selector values (for debugging)
export
registeredSelectors : List SomeEntry -> List Integer
registeredSelectors = map someEntrySelector
