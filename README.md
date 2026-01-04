# idris2-subcontract

**Subcontract framework for Idris2 - UCS patterns on idris2-yul**

Provides ERC-7546 UCS (Upgradeable Clone for Scalable contracts) implementation and standard functions for building modular smart contracts in Idris2.

## Overview

idris2-subcontract provides:

- **ERC-7546 Proxy**: DELEGATECALL-based proxy forwarding to dictionary
- **Dictionary Contract**: Function selector -> implementation mapping
- **Standard Functions**: FeatureToggle, Clone, Receive
- **Type-Safe API**: ABI signatures, decoders, and entry points
- **Storage Capability**: Controlled storage access via `StorageCap`
- **Type-Safe Storage**: Phantom-typed `Ref`, `Storable` interface, `Schema` derivation
- **Compile-Time Invariants**: Bounded values, NonZero divisors, TokenBalance proofs
- **Access Control as Types**: `HasRole` proofs instead of runtime `require()`
- **Reentrancy Protection**: Linear-style `Lock` types prevent reentrancy at compile time
- **State Machine Proofs**: `ValidTransition` ensures only valid state changes compile

## Installation

### Using pack

Add to your `pack.toml`:

```toml
[custom.all.idris2-subcontract]
type = "local"
path = "/path/to/idris2-subcontract"
ipkg = "idris2-subcontract.ipkg"
```

Then build:

```bash
pack build idris2-subcontract
```

### Dependencies

- [idris2-yul](https://github.com/shogochiai/idris2-yul) - Idris2 to EVM/Yul compiler

## Module Structure

```
Subcontract/
├── Standards/
│   └── ERC7546/              # ERC-7546 implementation
│       ├── Slots.idr         # Constants (DICTIONARY_SLOT, etc.)
│       ├── Forward.idr       # Proxy forwarding logic
│       ├── Proxy.idr         # Proxy exports
│       └── Dictionary.idr    # Dictionary contract
├── Core/
│   ├── Proxy.idr             # Re-exports Standards.ERC7546.Proxy
│   ├── Dictionary.idr        # Re-exports Standards.ERC7546.Dictionary
│   ├── Entry.idr             # Type-safe entry points
│   ├── StorageCap.idr        # Storage capability token
│   ├── Storable.idr          # Type → slot layout derivation
│   ├── Schema.idr            # Schema definitions for storage
│   ├── Derived.idr           # Schema derivation, state machines
│   ├── Invariants.idr        # Bounded, NonZero, TokenBalance
│   ├── AccessControl.idr     # HasRole proofs, RBAC
│   ├── Reentrancy.idr        # Lock types for reentrancy guard
│   ├── Call.idr              # Type-safe external calls
│   ├── Gas.idr               # Compile-time gas modeling
│   ├── Effects.idr           # Effect-typed entries, CEI safety
│   ├── Epoch.idr             # Epoch-indexed upgrades
│   ├── LinearAsset.idr       # Linear-persistent assets
│   └── ABI/
│       ├── Sig.idr           # Function signatures
│       └── Decoder.idr       # Calldata decoding
└── Std/
    └── Functions/
        ├── FeatureToggle.idr # Admin feature toggle
        ├── Clone.idr         # EIP-1167 proxy cloning
        └── Receive.idr       # ETH receive handling
```

## Quick Start

### Basic Proxy Contract

```idris
import Subcontract.Core.Proxy

main : IO ()
main = proxyMain
```

### Type-Safe Entry Points

```idris
import Subcontract.Core.Entry
import Subcontract.Core.ABI.Sig
import Subcontract.Core.ABI.Decoder

-- Define signature
addMemberSig : Sig
addMemberSig = MkSig "addMember(address,bytes32)"

addMemberSel : Sel addMemberSig
addMemberSel = MkSel 0x12345678

-- Create entry point
addMemberEntry : Entry addMemberSig
addMemberEntry = MkEntry addMemberSel $ do
  (addr, meta) <- runDecoder (decodeAddress <&> decodeBytes32)
  idx <- addMemberImpl (addrValue addr) (bytes32Value meta)
  returnUint idx

-- Dispatch
main : IO ()
main = dispatch [entry addMemberEntry]
```

### Storage Capability Pattern

```idris
import Subcontract.Core.StorageCap

-- Handler receives StorageCap from framework
myHandler : Handler Integer
myHandler cap = do
  val <- sloadCap cap SLOT_DATA
  sstoreCap cap SLOT_DATA (val + 1)
  pure val

-- Framework provides capability
main : IO ()
main = do
  result <- runHandler myHandler
  returnUint result
```

### Feature Toggle

```idris
import Subcontract.Std.Functions.FeatureToggle

myFunction : IO ()
myFunction = do
  shouldBeActive 0x12345678  -- Revert if disabled
  -- ... function logic
```

### Type-Safe Storage (Storable)

```idris
import Subcontract.Core.Storable

-- Define a record with automatic slot layout
record Member where
  constructor MkMember
  addr : Bits256
  meta : Bits256

Storable Member where
  slotCount = 2
  toSlots m = [m.addr, m.meta]
  fromSlots [a, m] = MkMember a m

-- Phantom-typed reference ensures type safety
getMember : Ref Member -> IO Member
getMember ref = get ref  -- Type guarantees correct slot count
```

### Compile-Time Invariants

```idris
import Subcontract.Core.Invariants

-- Bounded values: value <= cap proven at compile time
maxSupply : Bounded 1000000
maxSupply = MkBounded 500000  -- Compiles: 500000 <= 1000000

-- NonZero: safe division without runtime checks
safeDiv : Nat -> NonZero -> Nat  -- Total function!

-- TokenBalance: balance <= totalSupply by construction
transfer : {supply : Nat}
        -> (amount : Nat)
        -> (sender : TokenBalance supply)
        -> (recipient : TokenBalance supply)
        -> (hasEnough : LTE amount (balance sender))      -- Proof required!
        -> (noOverflow : LTE (balance recipient + amount) supply)
        -> (TokenBalance supply, TokenBalance supply)
```

### Access Control as Types

```idris
import Subcontract.Core.AccessControl

-- Functions require proof of role - not runtime check!
transferOwnership : HasRole Owner currentOwner  -- Must provide proof
                 -> OwnerStorage
                 -> (newOwner : Bits256)
                 -> IO ()

-- Obtain proof at runtime, use at compile-time
main : IO ()
main = do
  caller <- getCaller
  mproof <- checkRole roleStore Owner caller
  case mproof of
    Nothing => revert  -- No proof available
    Just prf => transferOwnership prf store newOwner  -- Proof provided
```

### Reentrancy Protection (Linear Types)

```idris
import Subcontract.Core.Reentrancy

-- Lock is CONSUMED when acquired - prevents reentrancy at compile time
withdraw : Lock Unlocked -> Amount -> IO (Lock Unlocked, Bool)
withdraw lock amount = do
  locked <- acquireLock lock     -- Lock Unlocked -> Lock Locked
  success <- call recipient amount
  unlocked <- releaseLock locked -- Lock Locked -> Lock Unlocked
  pure (unlocked, success)

-- This CANNOT compile - lock is already consumed:
-- badWithdraw lock = withLock_ lock $ \_ => badWithdraw lock
--                                           ^-- Error: lock consumed!
```

### Type-Safe External Calls

```idris
import Subcontract.Core.Call

-- Typed call with explicit return type
result <- typedCall @Bits256 (callTo target gas) calldata
case result of
  CallSuccess balance => use balance  -- Already typed!
  CallReverted _ => handleError

-- Safe ERC20 transfer
success <- safeTransfer token recipient amount gas
```

### Compile-Time Gas Modeling

```idris
import Subcontract.Core.Gas

-- Gas cost is part of the TYPE
erc20TransferSeq : GasSeq 44400  -- Compile-time constant
erc20TransferSeq = Then
  (Then (Op ColdSLoad) (Op ColdSLoad))  -- Read balances
  (Then (Op SStore) (Op SStore))        -- Write balances

-- Prove gas fits limit at compile time
erc20FitsLimit : GasFits TokenTransfer ERC20TransferGas
erc20FitsLimit = MkGasFits prf  -- LTE 44400 65000

-- Create bounded transaction - won't compile if exceeds limit!
tx : BoundedTx ComplexTx
tx = boundedTx ComplexTx computation gasSeq
```

### Effect-Typed Entries (CEI Safety)

```idris
import Subcontract.Core.Effects

-- Declare effects at type level
transferEffects : EffectList
transferEffects = [SLoad balanceSlot, SStore balanceSlot, Log 3]

-- CEI safety proof required - unsafe patterns won't compile
entry : {auto prf : CEISafe effs} -> EffectEntry effs

-- Write-before-Call detected at COMPILE TIME
unsafeEffects = [SStore slot, Call target]  -- Cannot get CEISafe proof!
```

### Epoch-Indexed Upgrades

```idris
import Subcontract.Core.Epoch

-- Functions tagged with epoch
myFunctionV1 : EpochFunction E0
myFunctionV2 : EpochFunction E1  -- Different type!

-- Migration with type-checked transformation
migrate : EpochState E0 OldData -> EpochState E1 NewData

-- Upgrade only allowed E0 -> E1 (no skipping)
upgrade : EpochTransition E0 E1 -> ...
```

### Linear-Persistent Assets

```idris
import Subcontract.Core.LinearAsset

-- SpendToken is LINEAR - use exactly once
spend : AssetStorage -> SpendToken asset -> IO ()  -- Token consumed

-- Double-spend impossible: token gone after first use
vote : SpendToken votingPower -> Choice -> IO ()
vote token choice = spend store token  -- Can't use token again!

-- Lock/unlock for escrow
lockAsset : SpendToken asset -> IO (LockToken asset)
unlockAsset : LockToken asset -> IO (SpendToken asset)
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        idris2-subcontract                           │
├─────────────────────────────────────────────────────────────────────┤
│  Subcontract.Std.Functions.*     Application-level functions       │
│  Subcontract.Core.*              Framework core (Entry, StorageCap)│
│  Subcontract.Standards.ERC7546.* ERC-7546 implementation           │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ imports
┌──────────────────────────────▼──────────────────────────────────────┐
│                          idris2-yul                                 │
├─────────────────────────────────────────────────────────────────────┤
│  EVM.Primitives              All EVM FFI definitions               │
│  EVM.Storage.Namespace       ERC-7201 slot calculations            │
│  EVM.ABI.*                   ABI encoding/decoding                 │
│  Compiler.EVM.*              Yul code generation                   │
└─────────────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Package | Responsibility |
|-------|---------|----------------|
| FFI | idris2-yul | `%foreign "evm:*"` primitives |
| Storage | idris2-yul | ERC-7201 slot calculations |
| Standards | idris2-subcontract | ERC-7546 proxy/dictionary |
| Framework | idris2-subcontract | Entry points, capabilities |
| Application | your-project | Business logic |

## ERC-7546 UCS Pattern

The Upgradeable Clone for Scalable contracts pattern:

```
┌─────────────┐     DELEGATECALL     ┌────────────────┐
│    Proxy    │ ──────────────────► │   Dictionary   │
│  (ERC-7546) │                      │ selector→impl  │
└─────────────┘                      └───────┬────────┘
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    │                        │                        │
              ┌─────▼─────┐           ┌──────▼──────┐          ┌──────▼──────┐
              │FeatureToggle│         │    Clone    │          │   Receive   │
              │  function  │          │  function   │          │  function   │
              └────────────┘          └─────────────┘          └─────────────┘
```

## Solidity vs Idris2 Comparison

| Concern | Solidity (Runtime) | Idris2 (Compile-Time) |
|---------|-------------------|----------------------|
| Non-negative | `uint256` (implicit) | `Nat` / `Amount` |
| Bounded value | `require(x <= cap)` | `Bounded cap` type |
| Non-zero divisor | `require(d != 0)` | `NonZero` type |
| Balance invariant | hope + audit | `TokenBalance supply` |
| Access control | `require(hasRole)` | `HasRole role addr` proof |
| Reentrancy guard | `bool _locked` + modifier | `Lock Unlocked/Locked` |
| State machine | enum + require | `PropTransition from to` |
| External calls | `(bool, bytes)` + decode | `CallResult a` typed |
| Gas estimation | runtime / RPC estimate | `GasSeq n` compile-time |
| CEI pattern | hope + audit | `CEISafe effs` proof |
| Upgrades | proxy swap, pray | `EpochTransition` typed |
| Double-spend | trust + mutex | `SpendToken` linear |

**Key insight**: In Solidity, invariants are runtime `require()` checks that can fail.
In Idris2, invariants are types - violation is a compile error.

## Related Projects

- [idris2-yul](https://github.com/shogochiai/idris2-yul) - Idris2 to EVM/Yul compiler
- [idris2-textdao](https://github.com/ecdysisxyz/idris2-textdao) - Example application
- [EIP-7546](https://eips.ethereum.org/EIPS/eip-7546) - UCS Proxy Standard

## Documentation

- [API Reference](docs/API.md) - Module API documentation
- [Storage Guide](docs/STORAGE.md) - EVM storage layout guide
- [Architecture](docs/ARCHITECTURE.md) - Layer design and rationale
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common integration issues

## License

MIT
