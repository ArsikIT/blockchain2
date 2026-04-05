# Blockchain Technologies 2 - Assignment 2

This repository is organized by assignment task so each contract, test, script, and document is grouped in a predictable place.

## Structure

- `src/task1/`
  - `MockERC20.sol`
- `src/task3/`
  - `AMM.sol`
  - `LPToken.sol`
- `src/task5/`
  - `LendingPool.sol`
  - `MockPriceOracle.sol`
- `test/task1/`
  - `MockERC20.t.sol`
  - `invariant/`
- `test/task2/`
  - `MainnetFork.t.sol`
- `test/task3/`
  - `AMM.t.sol`
- `test/task5/`
  - `LendingPool.t.sol`
- `script/task1/`
  - `DeployMockERC20.s.sol`
- `docs/task1/`
  - `README.md`
- `docs/task2/`
  - `README.md`
- `docs/task4/`
  - `README.md`
- `docs/task5/`
  - `README.md`
- `docs/task6/`
  - `README.md`

## Task Commands

### Task 1

```powershell
.\.foundry\bin\forge.exe test --match-path test/task1/MockERC20.t.sol -vvv
.\.foundry\bin\forge.exe test --match-path test/task1/invariant/MockERC20.invariant.t.sol -vvv
.\.foundry\bin\forge.exe coverage
```

### Task 2

Requires `.env` with `MAINNET_RPC_URL`.

```powershell
.\.foundry\bin\forge.exe test --match-path test/task2/MainnetFork.t.sol -vvv
```

### Task 3

```powershell
.\.foundry\bin\forge.exe test --match-path test/task3/AMM.t.sol -vvv
.\.foundry\bin\forge.exe test --match-path test/task3/AMM.t.sol --gas-report
```

### Task 5

```powershell
.\.foundry\bin\forge.exe test --match-path test/task5/LendingPool.t.sol -vvv
.\.foundry\bin\forge.exe test --match-path test/task5/LendingPool.t.sol --gas-report
```

### Task 6

- Workflow file: `.github/workflows/test.yml`
- Required GitHub secret: `MAINNET_RPC_URL`

## Notes

- `.env` is ignored by git.
- `cache/`, `out/`, and `broadcast/` are ignored by git.
- Foundry binaries are stored locally in `.foundry/bin/` for this project.
