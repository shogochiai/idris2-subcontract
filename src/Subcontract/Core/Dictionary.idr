||| Subcontract Core: ERC-7546 Dictionary Contract
|||
||| Manages function selector → implementation address mappings.
||| Part of the UCS (Upgradeable Clone for Scalable contracts) pattern.
|||
||| Reference: https://eips.ethereum.org/EIPS/eip-7546
module Subcontract.Core.Dictionary

import EVM.Storage.ERC7201

-- =============================================================================
-- Additional EVM Primitives
-- =============================================================================

%foreign "evm:caller"
prim__caller : PrimIO Integer

%foreign "evm:calldataload"
prim__calldataload : Integer -> PrimIO Integer

%foreign "evm:return"
prim__return : Integer -> Integer -> PrimIO ()

%foreign "evm:revert"
prim__revert : Integer -> Integer -> PrimIO ()

caller : IO Integer
caller = primIO prim__caller

calldataload : Integer -> IO Integer
calldataload off = primIO (prim__calldataload off)

evmReturn : Integer -> Integer -> IO ()
evmReturn off len = primIO (prim__return off len)

evmRevert : Integer -> Integer -> IO ()
evmRevert off len = primIO (prim__revert off len)

-- =============================================================================
-- Storage Layout
-- =============================================================================

||| Storage slot for owner address
export
SLOT_OWNER : Integer
SLOT_OWNER = 0

||| Base slot for implementations mapping
||| Actual slot = keccak256(selector . SLOT_IMPLEMENTATIONS_BASE)
export
SLOT_IMPLEMENTATIONS_BASE : Integer
SLOT_IMPLEMENTATIONS_BASE = 1

-- =============================================================================
-- Access Control
-- =============================================================================

||| Check if caller is owner
export
isOwner : IO Bool
isOwner = do
  owner <- sload SLOT_OWNER
  callerAddr <- caller
  pure (owner == callerAddr)

||| Require caller to be owner
export
requireOwner : IO ()
requireOwner = do
  ownerCheck <- isOwner
  if ownerCheck
    then pure ()
    else evmRevert 0 0

-- =============================================================================
-- Implementation Mapping
-- =============================================================================

||| Calculate storage slot for a function selector's implementation
export
getImplSlot : Integer -> IO Integer
getImplSlot selector = mappingSlot SLOT_IMPLEMENTATIONS_BASE selector

||| Get implementation address for a function selector
||| Returns 0 if not set
export
getImplementation : Integer -> IO Integer
getImplementation selector = do
  slot <- getImplSlot selector
  sload slot

||| Set implementation address for a function selector
||| Only owner can call
export
setImplementation : Integer -> Integer -> IO ()
setImplementation selector implAddr = do
  requireOwner
  slot <- getImplSlot selector
  sstore slot implAddr

||| Batch set multiple implementations
||| Only owner can call
export
batchSetImplementation : List (Integer, Integer) -> IO ()
batchSetImplementation [] = pure ()
batchSetImplementation ((sel, impl) :: rest) = do
  setImplementation sel impl
  batchSetImplementation rest

-- =============================================================================
-- Owner Management
-- =============================================================================

||| Get owner address
export
getOwner : IO Integer
getOwner = sload SLOT_OWNER

||| Transfer ownership (only owner can call)
export
transferOwnership : Integer -> IO ()
transferOwnership newOwner = do
  requireOwner
  sstore SLOT_OWNER newOwner

||| Initialize owner (should only be called once during deployment)
export
initializeOwner : Integer -> IO ()
initializeOwner owner = do
  currentOwner <- sload SLOT_OWNER
  if currentOwner == 0
    then sstore SLOT_OWNER owner
    else evmRevert 0 0  -- Already initialized

-- =============================================================================
-- Function Selectors
-- =============================================================================

||| getImplementation(bytes4) -> 0xdc9cc645
export
SEL_GET_IMPL : Integer
SEL_GET_IMPL = 0xdc9cc645

||| setImplementation(bytes4,address) -> 0x2c3c3e4e
export
SEL_SET_IMPL : Integer
SEL_SET_IMPL = 0x2c3c3e4e

||| owner() -> 0x8da5cb5b
export
SEL_OWNER : Integer
SEL_OWNER = 0x8da5cb5b

||| transferOwnership(address) -> 0xf2fde38b
export
SEL_TRANSFER : Integer
SEL_TRANSFER = 0xf2fde38b

||| initializeOwner(address) -> 0xc4d66de8
export
SEL_INITIALIZE : Integer
SEL_INITIALIZE = 0xc4d66de8

-- =============================================================================
-- Entry Point Helpers
-- =============================================================================

%foreign "evm:mstore"
prim__mstore : Integer -> Integer -> PrimIO ()

dictMstore : Integer -> Integer -> IO ()
dictMstore off val = primIO (prim__mstore off val)

||| Extract function selector from calldata (first 4 bytes)
export
getSelector : IO Integer
getSelector = do
  data_ <- calldataload 0
  -- Shift right 224 bits to get first 4 bytes
  pure (data_ `div` 0x100000000000000000000000000000000000000000000000000000000)

||| Return a uint256 value
export
returnUint : Integer -> IO ()
returnUint val = do
  dictMstore 0 val
  evmReturn 0 32

-- =============================================================================
-- Entry Point
-- =============================================================================

||| Main entry point for Dictionary contract
||| Dispatches to appropriate function based on selector
export
main : IO ()
main = do
  selector <- getSelector

  if selector == SEL_GET_IMPL
    then do
      -- getImplementation(bytes4 selector)
      arg <- calldataload 4
      impl <- getImplementation arg
      returnUint impl

    else if selector == SEL_SET_IMPL
    then do
      -- setImplementation(bytes4 selector, address impl)
      sel <- calldataload 4
      impl <- calldataload 36
      setImplementation sel impl
      evmReturn 0 0

    else if selector == SEL_OWNER
    then do
      -- owner()
      owner <- getOwner
      returnUint owner

    else if selector == SEL_TRANSFER
    then do
      -- transferOwnership(address newOwner)
      newOwner <- calldataload 4
      transferOwnership newOwner
      evmReturn 0 0

    else if selector == SEL_INITIALIZE
    then do
      -- initializeOwner(address owner)
      owner <- calldataload 4
      initializeOwner owner
      evmReturn 0 0

    else evmRevert 0 0  -- Unknown function
