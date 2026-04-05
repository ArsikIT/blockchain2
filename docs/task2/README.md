# Task 2: Fork Testing Against Mainnet

## What This Task Includes

This task uses Foundry fork testing to execute tests against a forked copy of Ethereum mainnet. The project includes:

- A test that reads `USDC.totalSupply()` from the real mainnet USDC contract
- A test that simulates a `Uniswap V2` swap through the real router contract
- A test that demonstrates `vm.rollFork`
- A test that shows how multiple forks can be created and selected

The fork tests are located in [MainnetFork.t.sol](C:\Users\hp\blockchain2 assignment2\test\task2\MainnetFork.t.sol).

## How `vm.createSelectFork` Works

`vm.createSelectFork(rpcUrl)` tells Foundry to connect to the RPC endpoint, create a local fork of that chain state, and immediately switch the current test context to that fork. In practice, this means the test can read real deployed contracts and interact with them as if it were running on mainnet, but without broadcasting real transactions. It is useful when you want realistic integration tests against existing protocols, token contracts, and live liquidity pools.

In this project, `vm.createSelectFork` is used in `setUp()` so every fork test starts from a real mainnet state. That makes the USDC supply read and Uniswap V2 swap test run against actual deployed contracts rather than mocks.

## How `vm.rollFork` Works

`vm.rollFork(newBlockNumber)` advances the currently selected fork to another block. This is useful when a test needs a later state, for example to simulate time progression, inspect protocol behavior after several blocks, or verify logic that depends on block numbers. It does not mine blocks on the real network; it only changes the block height of the local forked state inside the test environment.

In this task, `vm.rollFork` is demonstrated with a test that moves the fork forward by `5` blocks and verifies that the block number changed as expected.

## Benefits of Fork Testing

- It tests against real deployed contracts instead of simplified mocks.
- It reveals integration issues that unit tests may miss, such as incorrect interfaces, router assumptions, or token behavior differences.
- It is much cheaper and safer than running experiments directly on mainnet.
- It is especially useful for DeFi, where contract interactions often depend on live liquidity pools, real tokens, and existing protocol infrastructure.

## Limitations of Fork Testing

- It depends on an RPC provider, so test execution is not fully self-contained.
- Results can vary depending on the selected block and the live protocol state.
- Fork tests are slower than pure local unit tests.
- They are good for integration realism, but they do not replace unit tests and invariants for internal contract logic.

## How To Run

1. Create a `.env` file in the project root.
2. Copy the value from `.env.example`.
3. Replace `YOUR_API_KEY` with a real Ethereum mainnet RPC key.
4. Run the fork tests.

Example `.env`:

```powershell
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
```

Run command:

```powershell
.\.foundry\bin\forge.exe test --match-path test/task2/MainnetFork.t.sol -vvv
```

Foundry automatically loads `.env`, and `foundry.toml` maps `mainnet = "${MAINNET_RPC_URL}"`.

If the RPC URL is valid, Foundry will fork mainnet and execute the tests against the real contracts.
