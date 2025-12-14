# 1️⃣ WHAT THE SYSTEM DOES (CLEAN RESTATEMENT)

This protocol is a **Dynamic Vesting + Liquidity-Backed Pricing System**.

At a high level:

* Users lock tokens into a vesting contract
* They receive **shares** representing their claim
* A portion of vested tokens is used as **liquidity in a Uniswap V3 pool**
* The protocol **monitors the token price** from that pool
* If price is:

  * **Healthy (above threshold)** → vesting becomes more favorable
  * **Unhealthy (below threshold)** → vesting slows, pauses, or penalizes
* Price checks and adjustments are done **automatically**, optionally via Chainlink Automation

This creates a **self-regulating vesting system** tied to real market price discovery.

---

# 2️⃣ CORE SMART CONTRACTS (SEPARATION OF CONCERNS)

We intentionally split responsibilities so **each contract does ONE job well**.

## 🧩 A. Vesting Core Contract

**Responsibility:**

* Owns vesting schedules
* Tracks locked tokens
* Handles periodic claims
* Mints & burns vesting shares

**Does NOT:**

* Read price directly
* Manage Uniswap pools
* Decide how vesting adjusts

### Key responsibilities:

* Create vesting schedule
* Track:

  * total vested
  * claimed amount
  * vesting rate
* Allow `claim()` when allowed
* Ask another contract: *“Am I allowed to release tokens now?”*

📌 This contract is **policy-agnostic**.

---

## 🧩 B. Vesting Share Token (ERC20)

**Responsibility:**

* Represents claims on vested tokens
* Minted on deposit
* Burned on claim

**Does NOT:**

* Know vesting rules
* Know prices
* Know Uniswap

📌 This is a **dumb ERC20** with mint/burn access control.

---

## 🧩 C. Liquidity Manager (Uniswap V3)

**Responsibility:**

* Manages Uniswap V3 liquidity
* Adds vested tokens to pool
* Removes liquidity when needed
* Collects fees

**Does NOT:**

* Know vesting schedules
* Know price thresholds
* Decide unlock rules

📌 This is purely **execution-layer logic**.

---

## 🧩 D. Price Oracle Adapter (Uniswap V3 TWAP)

**Responsibility:**

* Reads price from Uniswap V3 pool
* Computes TWAP
* Returns normalized price

**Does NOT:**

* Store vesting logic
* Modify state outside oracle
* Trigger vesting changes

📌 This is a **read-only oracle adapter**.

---

## 🧩 E. Vesting Policy / Risk Engine

**Responsibility:**

* Compares price vs threshold
* Decides:

  * accelerate vesting
  * decelerate vesting
  * pause vesting
* Outputs parameters for VestingCore

**Does NOT:**

* Hold funds
* Interact with Uniswap
* Mint/burn tokens

📌 This is where **economic logic lives**.

---

## 🧩 F. Automation / Keeper Contract (Optional)

**Responsibility:**

* Periodically checks price
* Triggers policy updates
* Works with Chainlink Automation

**Does NOT:**

* Store vesting logic
* Compute prices
* Hold funds

📌 This is **pure automation glue**.

---

# 3️⃣ HOW THESE CONTRACTS TALK TO EACH OTHER (LOOSE COUPLING)

### ❌ What we avoid

* Importing concrete contract implementations
* Calling internal functions across contracts
* Hardcoding addresses

### ✅ What we use instead

* Interfaces
* Manager contracts
* Dependency injection

---

## 🔗 Interfaces (Core Communication)

### IVestingCore

```solidity
interface IVestingCore {
    function updateVestingRate(uint256 scheduleId, uint256 newRate) external;
    function pauseVesting(uint256 scheduleId) external;
    function resumeVesting(uint256 scheduleId) external;
}
```

### IPriceOracle

```solidity
interface IPriceOracle {
    function getPrice() external view returns (uint256);
}
```

### IVestingPolicy

```solidity
interface IVestingPolicy {
    function evaluatePrice(uint256 price) external returns (PolicyDecision);
}
```

### ILiquidityManager

```solidity
interface ILiquidityManager {
    function addLiquidity(uint256 amount) external;
}
```

---

## 🔁 Example Flow (Healthy Price)

1. Keeper calls `checkUpkeep()`
2. Keeper reads price via `IPriceOracle`
3. Keeper calls `IVestingPolicy.evaluatePrice(price)`
4. Policy returns:

   * `ACCELERATE_VESTING`
5. Keeper calls:

   * `IVestingCore.updateVestingRate(...)`

📌 VestingCore does not care **why** the rate changed — only that it was instructed to.

---

# 4️⃣ UPGRADE & EXTENSION STRATEGY (VERY IMPORTANT)

## 🔓 Open for Extension

You can:

* Replace the oracle (Chainlink → Uniswap → hybrid)
* Replace vesting policy logic
* Add new liquidity strategies
* Add multiple vesting policies per schedule

All without touching VestingCore.

---

## 🔁 Upgrade Strategy Options

### Option A — Replace Modules (Preferred)

* Deploy new Policy / Oracle
* Update addresses in a Registry
* VestingCore reads from Registry

### Option B — UUPS / Proxy (Optional)

* Proxy only VestingCore
* Other modules remain immutable

📌 For hackathon: **Option A is simpler and safer**.

---

# 5️⃣ FINAL CONTRACT LIST (AUTHORITATIVE)

| Contract             | Responsibility             |
| -------------------- | -------------------------- |
| VestingCore.sol      | Vesting schedules & claims |
| VestingShares.sol    | ERC20 vesting shares       |
| LiquidityManager.sol | Uniswap V3 LP execution    |
| TWAPOracle.sol       | Price reading              |
| VestingPolicy.sol    | Price → vesting logic      |
| Keeper.sol           | Automation & orchestration |
| AddressRegistry.sol  | Dependency injection       |

---

# 6️⃣ WHY THIS DESIGN IS STRONG

✅ Strict separation of concerns
✅ Loosely coupled
✅ Replaceable modules
✅ Easy to test in isolation
✅ Easy to extend post-hackathon
✅ Judges will recognize proper protocol architecture

---

# NEXT STEP (RECOMMENDED)

Before coding, the **correct next step** is:

👉 **Define exact vesting rules & math**

* How fast does vesting accelerate?
* What happens when price drops?
* Are penalties linear or step-based?
* How often can policy update rates?

If you want, next I can:

* Define **precise vesting formulas**
* Draw a **sequence diagram**
* Produce a **clean contract skeleton**
* Or design the **Policy Engine in detail**

Just tell me what to do next.
