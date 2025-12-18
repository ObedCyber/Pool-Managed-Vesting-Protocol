Excellent — these are **exactly the right questions**, and your instincts are already correct. I’ll answer **directly, practically, and in build-order**, not theory.

I’ll assume:

* Your **vested token = native protocol token**
* You’re using **Uniswap V3 Periphery (`NonfungiblePositionManager`)**
* You want **hackathon-speed correctness**

---

# 1️⃣ WHERE DO YOU START FROM? (ACTUAL BUILD ORDER)

### ✅ Start from **LiquidityManager.sol**, NOT Uniswap

Reason:

* LiquidityManager defines **how your protocol touches Uniswap**
* It dictates required interfaces, permissions, and flows
* Everything else plugs into it later

### Concrete first steps:

1. Create `ILiquidityManager.sol`
2. Create `LiquidityManager.sol`
3. Inject:

   * `INonfungiblePositionManager`
   * `UniswapV3Factory`
4. Hardcode (for MVP):

   * fee tier = `3000`
   * tick range = wide

📌 Do **NOT** start by writing pool logic or oracle logic.

---

# 2️⃣ IF VESTED TOKEN IS token0, WHAT IS token1?

### Short answer:

**A stable asset. Always.**

### Recommended options:

| Token1 | Why                    |
| ------ | ---------------------- |
| USDC   | Stable, judge-friendly |
| USDT   | Acceptable             |
| WETH   | ❌ not ideal (volatile) |

📌 Since your protocol logic depends on **price thresholds**, you need:

> **Your token / USD pair**

### Practical setup:

* token0 = YOUR_TOKEN
* token1 = USDC
* price = YOUR_TOKEN per USDC

📌 This makes TWAP meaningful.

---

# 3️⃣ DO YOU CREATE THE UNISWAP POOL YOURSELF?

### Short answer:

**Yes — but indirectly.**

### Important truth:

> `NonfungiblePositionManager.mint()`
> **creates the pool automatically IF it doesn’t exist**

You have **two valid approaches**:

---

### 🅰️ Option A (Recommended for Hackathon)

Let `NonfungiblePositionManager` handle it.

Flow:

1. Call `mint()`
2. If pool doesn’t exist:

   * it creates it
   * initializes it
3. LP NFT is minted

📌 Fast, clean, safe.

---

### 🅱️ Option B (Manual Pool Creation)

You explicitly:

1. Call `factory.createPool()`
2. Initialize price via `initialize()`
3. Then mint liquidity

📌 More control, more code, more risk.

---

### ✅ Hackathon Verdict:

**Use Option A.**

Judges prefer simplicity.

---

# 4️⃣ WHAT ROLES DO OTHER CONTRACTS PLAY IN LiquidityManager?

This is where your **architecture maturity** shows.

LiquidityManager should **never be a god contract**.

---

## 🔗 Key External Contracts & Their Roles

### 🧩 1️⃣ VestingCore / Treasury

Role:

* Owns vested tokens
* Sends tokens to LiquidityManager

Interaction:

```text
VestingCore → LiquidityManager → Uniswap
```

LiquidityManager:
❌ doesn’t know vesting rules
✅ just receives tokens

---

### 🧩 2️⃣ Address Registry

Role:

* Stores addresses of:

  * LiquidityManager
  * Oracle
  * VestingCore
  * Governance

Why:

* Enables upgrades
* Avoids redeploying everything

📌 Hackathon judges LOVE this.

---

### 🧩 3️⃣ Access Control / Governance

Role:

* Controls who can:

  * add liquidity
  * remove liquidity
  * collect fees

LiquidityManager:

```solidity
modifier onlyManager()
```

---

### 🧩 4️⃣ Price Oracle (NO DIRECT LINK)

LiquidityManager:
❌ never calls oracle
❌ never reads price

This is intentional.

---

## 🧠 FINAL CONTRACT RELATIONSHIP MAP

```text
VestingCore
    |
    v
LiquidityManager  ---->  Uniswap V3
    |
    x  (no price logic)
    |
Registry
    |
    v
TWAP Oracle (read-only)
```

---

# 🧪 WHAT LiquidityManager MUST STORE

Minimal state:

```solidity
address public token0;
address public token1;
uint24 public fee;
uint256 public positionTokenId;
address public positionManager;
```

Optional:

* accumulated fees
* strategy parameters

---

# ⚠️ COMMON BEGINNER MISTAKES (AVOID)

❌ LiquidityManager holds user balances
❌ LiquidityManager calculates prices
❌ LiquidityManager manages vesting
❌ Multiple LP positions in MVP
❌ Over-configurable tick logic

---

# ✅ YOUR MVP LIQUIDITY MANAGER SHOULD:

✔ Create 1 pool
✔ Manage 1 LP NFT
✔ Accept tokens from VestingCore
✔ Add / remove liquidity
✔ Collect fees
✔ Be fully permissioned

That’s already **hackathon-winning**.

---

# 🔜 WHAT YOU SHOULD DO NEXT (VERY IMPORTANT)

Next, I strongly recommend:
👉 **Write a minimal LiquidityManager.sol skeleton**

* No Uniswap math
* Just function flow & interfaces

If you want, I can:

* Draft **LiquidityManager.sol (MVP-ready)**
* Draft **ILiquidityManager.sol**
* Help you choose **tick range**
* Help you set **initial price**
* Review your LiquidityManager once written

Just tell me the next step.
