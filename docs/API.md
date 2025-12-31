# idris2-mc API Reference

## Module: MC.Std.Storage.ERC7201

Core EVM storage primitives and ERC-7201 slot calculations.

### EVM Primitives

These wrap EVM opcodes for storage and memory operations:

```idris
-- Memory operations
mstore : Integer -> Integer -> IO ()       -- Store 32 bytes to memory
mload : Integer -> IO Integer              -- Load 32 bytes from memory
mstore8 : Integer -> Integer -> IO ()      -- Store 1 byte to memory

-- Storage operations
sload : Integer -> IO Integer              -- Load from storage slot
sstore : Integer -> Integer -> IO ()       -- Store to storage slot

-- Hashing
keccak256 : Integer -> Integer -> IO Integer  -- Hash memory range
```

### ERC-7201 Slot Calculation

```idris
||| Calculate ERC-7201 namespace root slot from pre-hashed ID
||| Formula: keccak256(keccak256(id) - 1) & ~0xff
|||
||| @param idHash - keccak256 hash of the namespace ID string
||| @return The aligned storage slot
erc7201FromHash : Integer -> IO Integer
```

**Example:**
```idris
-- For namespace "myapp.storage":
-- 1. Compute keccak256("myapp.storage") offline
-- 2. Pass that hash to erc7201FromHash
-- 3. Use the result as your schema's root slot
```

```idris
||| Align a slot to 256-byte boundary (pure version)
||| Equivalent to: slot & ~0xff
alignSlot : Integer -> Integer
```

### Solidity Storage Layout Functions

#### Mapping Slots

```idris
||| Calculate slot for mapping[key]
||| Formula: keccak256(key . baseSlot)
|||
||| @param baseSlot - Storage slot of the mapping variable
||| @param key - The mapping key (address, uint256, bytes32, etc.)
||| @return Storage slot for mapping[key]
mappingSlot : Integer -> Integer -> IO Integer
```

**Example:**
```idris
-- For: mapping(address => uint256) balances; at slot 5
-- balances[0xABC...] is at:
slot <- mappingSlot 5 0xABC...
```

```idris
||| Calculate slot for nested mapping[key1][key2]
||| Formula: keccak256(key2 . keccak256(key1 . baseSlot))
|||
||| @param baseSlot - Storage slot of the outer mapping
||| @param key1 - First level key
||| @param key2 - Second level key
||| @return Storage slot for mapping[key1][key2]
nestedMappingSlot : Integer -> Integer -> Integer -> IO Integer
```

**Example:**
```idris
-- For: mapping(address => mapping(address => uint256)) allowance;
-- allowance[owner][spender] is at:
slot <- nestedMappingSlot baseSlot owner spender
```

#### Array Slots

```idris
||| Calculate slot for dynamic array element
||| Array length at baseSlot, data starts at keccak256(baseSlot)
||| Element i is at: keccak256(baseSlot) + i * elementSize
|||
||| @param baseSlot - Storage slot storing array.length
||| @param index - Array index
||| @param elementSize - Number of 32-byte slots per element
||| @return Storage slot for array[index]
arrayElementSlot : Integer -> Integer -> Integer -> IO Integer
```

**Example:**
```idris
-- For: address[] members; where each address uses 1 slot
-- members[3] is at:
slot <- arrayElementSlot membersSlot 3 1
```

```idris
||| Get array length
arrayLength : Integer -> IO Integer
```

#### Struct Slots

```idris
||| Calculate slot for struct field (pure)
||| Struct fields are contiguous: baseSlot + fieldOffset
|||
||| @param baseSlot - Storage slot of the struct
||| @param fieldOffset - Field's offset (0-indexed)
||| @return Storage slot for the field
structFieldSlot : Integer -> Integer -> Integer
```

**Example:**
```idris
-- For: struct User { address addr; uint256 balance; }
-- user.balance (field 1) is at:
let slot = structFieldSlot userSlot 1
```

### Type-Safe Accessors

```idris
-- Uint256
readUint : Integer -> IO Integer
writeUint : Integer -> Integer -> IO ()

-- Address (masked to 160 bits on read)
readAddress : Integer -> IO Integer
writeAddress : Integer -> Integer -> IO ()

-- Bool
readBool : Integer -> IO Bool
writeBool : Integer -> Bool -> IO ()

-- Selector (bytes4, masked to 32 bits)
readSelector : Integer -> IO Integer
```

### Struct Layout Helper

```idris
||| Field layout definition
record FieldLayout where
  constructor MkField
  offset : Integer   -- Slot offset from struct base
  size : Integer     -- Number of slots

||| Calculate total struct size
structSize : List FieldLayout -> Integer

||| Get field slot
accessField : Integer -> FieldLayout -> Integer
```

### Pre-computed Constants

MC framework standard namespace slots:

| Constant | Namespace | Description |
|----------|-----------|-------------|
| `SLOT_MC_ADMIN` | mc.std.admin | Admin address storage |
| `SLOT_MC_CLONE` | mc.std.clone | Proxy dictionary address |
| `SLOT_MC_MEMBER` | mc.std.member | Member list |
| `SLOT_MC_FEATURE_TOGGLE` | mc.std.featureToggle | Feature toggle mapping |
| `SLOT_MC_INITIALIZATION` | mc.std.initialization | Initialization state |

---

## Module: MC.Std.Storage.Schema

Declarative schema definition DSL for ERC-7201 storage.

### Storage Types

```idris
data StorageType
  = TUint256      -- uint256 (32 bytes)
  | TUint128      -- uint128 (16 bytes, typically 1 slot)
  | TUint64       -- uint64 (8 bytes)
  | TUint32       -- uint32 (4 bytes)
  | TUint8        -- uint8 (1 byte)
  | TInt256       -- int256 (32 bytes, signed)
  | TAddress      -- address (20 bytes)
  | TBool         -- bool (1 byte)
  | TBytes32      -- bytes32 (32 bytes)
  | TBytes4       -- bytes4 (4 bytes, function selector)
```

```idris
||| Get slot size for a type (always 1 for non-packed)
typeSlotSize : StorageType -> Integer
```

### Field Definitions

```idris
data FieldDef : Type where
  ||| Simple value: field name, type, slot offset
  ValueField : String -> StorageType -> Integer -> FieldDef

  ||| Mapping: name, key type, value type, offset
  MappingField : String -> StorageType -> StorageType -> Integer -> FieldDef

  ||| Nested mapping: name, key1 type, key2 type, value type, offset
  NestedMappingField : String -> StorageType -> StorageType -> StorageType -> Integer -> FieldDef

  ||| Dynamic array: name, element size (slots), offset
  ArrayField : String -> Integer -> Integer -> FieldDef

  ||| Nested struct: name, struct size (slots), offset
  StructField : String -> Integer -> Integer -> FieldDef
```

```idris
||| Get field name
fieldName : FieldDef -> String

||| Get field offset
fieldOffset : FieldDef -> Integer
```

### Schema Record

```idris
record Schema where
  constructor MkSchema
  namespaceId : String      -- ERC-7201 namespace (e.g., "myapp.storage")
  rootSlot : Integer        -- Pre-computed ERC-7201 root slot
  fields : List FieldDef    -- Field definitions
```

**Example:**
```idris
-- Equivalent to Solidity:
-- /// @custom:storage-location erc7201:myapp.token
-- struct $Token {
--     uint256 totalSupply;
--     mapping(address => uint256) balances;
--     mapping(address => mapping(address => uint256)) allowances;
-- }

TokenSchema : Schema
TokenSchema = MkSchema
  "myapp.token"
  0x...  -- pre-computed slot
  [ ValueField "totalSupply" TUint256 0
  , MappingField "balances" TAddress TUint256 1
  , NestedMappingField "allowances" TAddress TAddress TUint256 2
  ]
```

### Schema Accessors

```idris
||| Get root slot
schemaRoot : Schema -> Integer

||| Get absolute slot for a field by name
getFieldSlot : Schema -> String -> Maybe Integer
```

### High-Level Access Functions

```idris
||| Read a value field
accessValue : Schema -> String -> IO (Maybe Integer)

||| Read from a mapping field
accessMapping : Schema -> String -> Integer -> IO (Maybe Integer)

||| Read from a nested mapping field
accessNestedMapping : Schema -> String -> Integer -> Integer -> IO (Maybe Integer)

||| Read an array element
accessArrayElement : Schema -> String -> Integer -> Integer -> IO (Maybe Integer)

||| Get array length
getArrayLength : Schema -> String -> IO (Maybe Integer)
```

**Example:**
```idris
-- Read totalSupply
totalSupply <- accessValue TokenSchema "totalSupply"

-- Read balances[addr]
balance <- accessMapping TokenSchema "balances" addr

-- Read allowances[owner][spender]
allowance <- accessNestedMapping TokenSchema "allowances" owner spender
```

### Example Schemas (MC Standard)

Pre-defined schemas for MC framework compatibility:

```idris
AdminSchema          -- { address admin; }
CloneSchema          -- { address dictionary; }
MemberSchema         -- { address[] members; }
FeatureToggleSchema  -- { mapping(bytes4 => bool) disabledFeature; }
InitializationSchema -- { uint64 initialized; bool initializing; }
```

### Convenience Functions

For MC standard schemas:

```idris
readAdmin : IO Integer
writeAdmin : Integer -> IO ()
readDictionary : IO Integer
isFeatureDisabled : Integer -> IO Bool
toggleFeature : Integer -> IO ()
isInitialized : IO Bool
getMemberAt : Integer -> IO Integer
getMemberCount : IO Integer
```
