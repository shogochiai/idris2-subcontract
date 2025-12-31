# idris2-mc

**Idris2 implementation of the MC (MetaContract) framework**

A type-safe EVM storage library providing ERC-7201 namespaced storage and declarative schema definitions for Idris2 smart contracts.

## Overview

idris2-mc provides:

- **ERC-7201 Storage Slots**: Namespaced storage location calculation following [EIP-7201](https://eips.ethereum.org/EIPS/eip-7201)
- **Schema DSL**: Declarative storage schema definitions similar to Solidity structs
- **Slot Calculations**: Mapping, array, and nested struct slot computation
- **Type-Safe Accessors**: Read/write functions with type information

## Installation

### Using pack

Add to your `pack.toml`:

```toml
[custom.all.idris2-mc]
type = "local"
path = "/path/to/idris2-mc"
ipkg = "idris2-mc.ipkg"
```

Then install:

```bash
pack install idris2-mc
```

### Manual

Add to your `.ipkg` file:

```
depends = idris2-mc
```

## Quick Start

```idris
import MC.Std.Storage.ERC7201
import MC.Std.Storage.Schema

-- Define your schema with pre-computed ERC-7201 slot
MySchema : Schema
MySchema = MkSchema
  "myapp.storage"                              -- namespace ID
  0x1234...                                    -- pre-computed root slot
  [ ValueField "owner" TAddress 0              -- address owner; at offset 0
  , MappingField "balances" TAddress TUint256 1 -- mapping(address => uint256); at offset 1
  ]

-- Access storage
getOwner : IO Integer
getOwner = do
  let slot = schemaRoot MySchema
  readAddress slot

getBalance : Integer -> IO Integer
getBalance addr = do
  case getFieldSlot MySchema "balances" of
    Nothing => pure 0
    Just baseSlot => do
      slot <- mappingSlot baseSlot addr
      sload slot
```

## Core API

### ERC-7201 Slot Calculation

```idris
-- Calculate ERC-7201 root slot from namespace hash
-- Formula: keccak256(keccak256(id) - 1) & ~0xff
erc7201FromHash : Integer -> IO Integer

-- Pre-compute offline:
-- cast keccak "myapp.storage"
-- Then apply ERC-7201 formula
```

### Solidity Storage Layout

```idris
-- Mapping slot: keccak256(key . baseSlot)
mappingSlot : Integer -> Integer -> IO Integer

-- Nested mapping: mapping[key1][key2]
nestedMappingSlot : Integer -> Integer -> Integer -> IO Integer

-- Dynamic array element: keccak256(baseSlot) + index * elementSize
arrayElementSlot : Integer -> Integer -> Integer -> IO Integer

-- Struct field: baseSlot + fieldOffset
structFieldSlot : Integer -> Integer -> Integer
```

### Schema Definition

```idris
-- Storage types
data StorageType
  = TUint256 | TUint128 | TUint64 | TUint32 | TUint8
  | TInt256 | TAddress | TBool | TBytes32 | TBytes4

-- Field definitions
data FieldDef
  = ValueField String StorageType Integer
  | MappingField String StorageType StorageType Integer
  | NestedMappingField String StorageType StorageType StorageType Integer
  | ArrayField String Integer Integer
  | StructField String Integer Integer

-- Schema record
record Schema where
  constructor MkSchema
  namespaceId : String
  rootSlot : Integer
  fields : List FieldDef
```

### Type-Safe Accessors

```idris
readUint : Integer -> IO Integer
writeUint : Integer -> Integer -> IO ()

readAddress : Integer -> IO Integer
writeAddress : Integer -> Integer -> IO ()

readBool : Integer -> IO Bool
writeBool : Integer -> Bool -> IO ()
```

## Pre-computed MC Standard Slots

For compatibility with the original MC framework:

```idris
SLOT_MC_ADMIN          -- mc.std.admin
SLOT_MC_CLONE          -- mc.std.clone
SLOT_MC_MEMBER         -- mc.std.member
SLOT_MC_FEATURE_TOGGLE -- mc.std.featureToggle
SLOT_MC_INITIALIZATION -- mc.std.initialization
```

These are provided as examples. Define your own namespaces for your application.

## Computing ERC-7201 Slots

Use `cast` (from Foundry) to compute slots offline:

```bash
# 1. Hash the namespace ID
HASH=$(cast keccak "myapp.storage")

# 2. Subtract 1
MINUS_ONE=$(cast --to-int256 $(python3 -c "print(int('$HASH', 16) - 1)"))

# 3. Hash again
HASH2=$(cast keccak $(cast --to-bytes32 $MINUS_ONE))

# 4. Align to 256 bytes (mask with ~0xff)
SLOT=$(python3 -c "print(hex(int('$HASH2', 16) & ~0xff))")

echo "Root slot: $SLOT"
```

Or use Solidity:

```solidity
bytes32 slot = keccak256(abi.encode(keccak256("myapp.storage") - 1)) & ~bytes32(uint256(0xff));
```

## Project Structure

```
idris2-mc/
├── src/MC/Std/Storage/
│   ├── ERC7201.idr    -- Core slot calculations
│   └── Schema.idr     -- Schema DSL
├── examples/          -- Example contracts
├── test/              -- Tests
└── idris2-mc.ipkg     -- Package definition
```

## Related Projects

- [idris2-yul](https://github.com/shogochiai/idris2-yul) - Idris2 to EVM/Yul compiler
- [metacontract/mc](https://github.com/metacontract/mc) - Original Solidity MC framework
- [EIP-7201](https://eips.ethereum.org/EIPS/eip-7201) - Namespaced Storage Layout

## License

MIT
