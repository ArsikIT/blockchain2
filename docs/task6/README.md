# Task 6: GitHub Actions for Smart Contracts

## Overview

This task adds a CI pipeline for the Foundry smart contract project. The workflow is defined in:

- [test.yml](C:\Users\hp\blockchain2 assignment2\.github\workflows\test.yml)

The pipeline is designed to validate the project automatically on every push, pull request, and manual workflow run.

## Pipeline Stages

### 1. Checkout Repository

The workflow starts by checking out the repository source code. This makes all contracts, tests, scripts, and documentation available inside the GitHub Actions runner.

### 2. Install Foundry

The pipeline installs Foundry using the official `foundry-rs/foundry-toolchain` action. This provides `forge`, which is required to build and test the smart contracts.

### 3. Validate Required Secret

Fork tests from Task 2 depend on a real Ethereum mainnet RPC URL. Because GitHub Actions does not have access to the local `.env` file, the pipeline expects a repository secret named `MAINNET_RPC_URL`. A dedicated validation step fails early if that secret is missing.

### 4. Build Contracts

The workflow runs `forge build` to compile all contracts. This ensures the Solidity code is syntactically correct and all imports resolve properly before testing begins.

### 5. Run All Tests

The workflow runs `forge test -vvv`, which executes:

- Task 1 unit tests
- Task 1 invariant tests
- Task 2 fork tests
- Task 3 AMM tests
- Task 5 lending pool tests

This provides a single CI gate for the entire assignment project.

### 6. Generate Gas Reports

The pipeline separately runs gas reports for:

- Task 3 AMM tests
- Task 5 LendingPool tests

This gives measurable execution cost data for the most important protocol contracts.

### 7. Run Slither

The final stage runs `Slither`, a static analysis tool for Solidity. Slither helps detect security issues, code quality problems, and dangerous patterns that normal unit tests may not catch.

## Required GitHub Secret

Add this repository secret before running the workflow:

- `MAINNET_RPC_URL`

GitHub path:

- `Settings -> Secrets and variables -> Actions -> New repository secret`

The value should be your Ethereum mainnet RPC URL, for example an Alchemy endpoint.

## Local/Manual Verification

After pushing the workflow file to GitHub:

1. Open the repository on GitHub
2. Go to the `Actions` tab
3. Open the `Smart Contracts CI` workflow
4. Verify the run is successful
5. Take a screenshot of the successful run for submission

If needed, the workflow can also be simulated locally with `act`, which is allowed by the assignment.
