Excellent. You’re now at the **“architect + executor”** phase — exactly where hackathon winners operate.

Below is a **clear, time-boxed roadmap** + a **clean LiquidityManager contract layout** that respects:

* address registry abstraction
* interface-based design
* separation of concerns
* hackathon time constraints (8 days)

No overengineering, but **very professional**.

---

# 🗺️ PART 1 — 8-DAY ROADMAP (REALISTIC & WINNABLE)

## 🗓️ DAY 1 — Architecture & Interfaces (TODAY)

**Goal:** Lock structure so you never rewrite.

### Deliverables:

* `IAddressRegistry.sol`
* `ILiquidityManager.sol`
* `IPriceOracle.sol` (stub)
* Folder structure finalized

📌 No Uniswap code yet.

---

## 🗓️ DAY 2 — LiquidityManager Skeleton

**Goal:** Execution-layer clarity.

### Deliverables:

* `LiquidityManager.sol`
* Constructor wiring (registry, position manager)
* Access control modifiers
* Event definitions

📌 Functions exist but are empty.

---

## 🗓️ DAY 3 — Uniswap V3 Integration

**Goal:** Actually talk to Uniswap.

### Deliverables:

* Pool creation via mint()
* Initial liquidity provision
* Position NFT tracking
* Remove liquidity logic

📌 Single pool, single position.

---

## 🗓️ DAY 4 — TWAP Oracle Adapter

**Goal:** Read-only price truth.

### Deliverables:

* `UniswapV3TWAPOracle.sol`
* TWAP computation
* Normalized price return

📌 No Chainlink yet.

---

## 🗓️ DAY 5 — Automation / Keeper Logic

**Goal:** Periodic health checks.

### Deliverables:

* Chainlink Automation-compatible contract
* Price threshold evaluation
* Signals vesting controller

📌 No business logic here.

---

## 🗓️ DAY 6 — Vesting Logic Adjustment

**Goal:** Dynamic unlock rules.

### Deliverables:

* Vesting schedule adjustment logic
* Interface-driven updates
* Guardrails & sanity checks

---

## 🗓️ DAY 7 — Testing & Edge Cases

**Goal:** Stability.

### Deliverables:

* LiquidityManager tests
* Oracle manipulation tests
* Permission tests

---

## 🗓️ DAY 8 — Polish & Pitch

**Goal:** Win.

### Deliverables:

* README architecture diagram
* Deployment flow
* Demo walkthrough

---

# 🧩 PART 2 — SMART CONTRACT LAYOUT (LIQUIDITY MANAGER)

This is **exactly** how your LiquidityManager should look architecturally.

---

## 📁 contracts/

```
contracts/
├── interfaces/
│   ├── ILiquidityManager.sol
│   ├── IAddressRegistry.sol
│   └── IUniswapV3.sol
│
├── core/
│   ├── LiquidityManager.sol
│   └── AddressRegistry.sol
│
├── oracles/
│   └── UniswapV3TWAPOracle.sol
```

---

# 🧾 ILiquidityManager.sol (INTERFACE FIRST)

```solidity
interface ILiquidityManager {
    function provideLiquidity(uint256 tokenAmount) external;
    function removeLiquidity(uint128 liquidity) external;
    function collectFees() external returns (uint256 amount0, uint256 amount1);
    function getPool() external view returns (address);
    function getPositionId() external view returns (uint256);
}
```

📌 Minimal. No vesting assumptions.

---

# 🧩 LiquidityManager.sol — FUNCTIONALITY LAYOUT

Below is **conceptual structure**, not full code.

---

## 1️⃣ State Variables

```solidity
address public immutable registry;
address public immutable positionManager;

address public token0; // vested token
address public token1; // USDC
uint24 public constant FEE = 3000;

uint256 public positionTokenId;
bool public poolInitialized;
```

---

## 2️⃣ Constructor

```solidity
constructor(
    address _registry,
    address _positionManager,
    address _token0,
    address _token1
) {
    registry = _registry;
    positionManager = _positionManager;
    token0 = _token0;
    token1 = _token1;
}
```

📌 No Uniswap logic here.

---

## 3️⃣ Modifiers

```solidity
modifier onlyManager() {
    require(msg.sender == IAddressRegistry(registry).getLiquidityController(), "Not authorized");
    _;
}
```

📌 Access control is externalized.

---

## 4️⃣ provideLiquidity()

```solidity
function provideLiquidity(uint256 amountToken)
    external
    onlyManager
{
    // 1. Transfer token0 from caller
    // 2. Approve position manager
    // 3. Mint or increase position
    // 4. Store positionTokenId if new
}
```

📌 Handles pool creation automatically.

---

## 5️⃣ removeLiquidity()

```solidity
function removeLiquidity(uint128 liquidity)
    external
    onlyManager
{
    // 1. Decrease liquidity
    // 2. Collect tokens
    // 3. Send to treasury / vesting
}
```

---

## 6️⃣ collectFees()

```solidity
function collectFees()
    external
    onlyManager
    returns (uint256 amount0, uint256 amount1)
{
    // Call collect()
    // Route fees
}
```

---

## 7️⃣ getPool()

```solidity
function getPool() external view returns (address) {
    return IUniswapV3Factory(
        INonfungiblePositionManager(positionManager).factory()
    ).getPool(token0, token1, FEE);
}
```

---

# 🧩 ROLE OF AddressRegistry

Your AddressRegistry should:

* store contract addresses
* allow upgrades
* prevent hardcoded dependencies

Example:

```solidity
function getLiquidityController() external view returns (address);
function getTreasury() external view returns (address);
function getOracle() external view returns (address);
```

LiquidityManager never stores these directly.

---

# 🏆 WHY THIS DESIGN IS HACKATHON-GRADE

✔ Modular
✔ Upgradeable
✔ Clean interfaces
✔ Uniswap V3 done correctly
✔ Oracle separated
✔ Automation-ready

Judges will instantly see:

> “This person understands protocol architecture.”

---

# 🔜 NEXT STEP (HIGH VALUE)

Next, I recommend:
👉 I write **a minimal LiquidityManager.sol implementation** (compilable)
OR
👉 I help you choose **tick ranges + initial price**
OR
👉 I review your AddressRegistry design

Tell me what you want next — you’re on track to win this.
