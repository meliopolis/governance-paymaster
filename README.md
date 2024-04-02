# Governance Paymasters

_This work was funded by the Ethereum Foundation._

This repository contains Paymasters that operate **fully on-chain**, as in without requiring a separate centralized backend service that determines whether a transaction should be covered by a Paymaster. 

### Why is this interesting?

Most paymasters today (like [VerifyingPaymaster](https://github.com/eth-infinitism/account-abstraction/blob/develop/contracts/samples/VerifyingPaymaster.sol)) require a backend service. They typically only verify whether `UserOp.paymasterAndData` contains a valid signature and relies on an external service to parse and validate transaction. While this is functional, it introduces a centralized service in the middle.

In this repository, we demonstrate several paymasters that don't need a centralized service. These paymasters work for only a specific action on-chain and they determine whether to pay for those actions with logic *completely on-chain*. Once deployed, they can operate without requiring any intervention (except to refill their accounts with `EntryPoint`).

### Table of Contents

* [General Overview](#general-overview)
* Paymasters
    1. [Paymaster for `delegate(address)`](#1-paymaster-for-delegateaddress-call)
    2. [Paymaster for `castVote(uint256,uint8)`](#2-paymaster-for-castvoteuint256uint8-call)
    3. [Paymaster for `delegate` or `castVote`](#3-paymaster-for-delegate-or-castvote-calls)
* [How to use](#usage) 


## General Overview

### Methodology

Main challenge for a fully on-chain paymaster is to cover **only** the transactions specified and avoid getting drained through various different abuse vectors. 

Our validation function checks for both the length and subsections of the calldata to ensure the call will only go to the intended contract and only call a specific function (like `delegate(address)`) on that contract. 

In each of the paymasters below, we specify the exact calldata required for the paymaster to approve.

### Other Considerations: attack vectors, gas costs, etc

* What if the user calls a paymaster again **immediately** or repeatedly after a successful action? In some cases, this is already limited by on-chain logic like a `GovernorBravo` contract won't allow same user to vote multiple times. In other cases, we record the user action and impose a minimum waiting time. 

* What if someone submits a transaction during high gas fees? There's a built-in `maxCost` to limit gas spend, also editable by the paymaster `owner`.

* What if there is a dishonest bundler who submits fake transactions? Then, (in theory), that bundler will get penalized by EntryPoint when the transaction fails during EntryPoint's simulation.

### Storage access rules

One of the reasons on-chain Paymasters are challenging to build is due to strict storage access rules that prevent attacks.

These paymaster respects all the storage access rules. They only access ERC20 Token balances, which is allowed by the [rule #3 in the specifications](https://eips.ethereum.org/EIPS/eip-4337#storage-associated-with-an-address). Additionally, the Paymaster accesses its own storage and that requires it to stake with EntryPoint (which our deploy script handles).

Update: This might be changing in the latest version per Dror and Tom from EF. Waiting to confirm.

### Governor Support

We initially built these paymasters for [`GovernorBravo`](https://etherscan.io/address/0x408ED6354d4973f66138C91495F2f2FCbd8724C3) and later tested them successfully for OpenZeppelin's [`Governor`](https://docs.openzeppelin.com/contracts/5.x/governance#governor) contract.

<details>
<summary> Testing with `GovernorBravo`</summary>

Check out scripts `05_DeployGovernorBravo...` to `08_GBCastVote.s.sol`. These scripts will

* deploy all the necessary contracts: `Uni` token, `Timelock`, and `GovernorBravo`
* generating transfers and delegates
* create a proposal
* cast a vote (for an EOA on a local testnet) 

You'll need to update some the variables in `.env` (scripts will let you know).
</details>

<details>
<summary> Testing with OpenZeppelin's `Governor`</summary>

Check out scripts `09_DeployOZGovernor...` to `12_OZBCastVote.s.sol`. These scripts will

* deploy all the necessary contracts: `ERC20Test` token, `TimelockController`, and `Governor`
* generating transfers and delegates
* create a proposal
* cast a vote (for an EOA on a local testnet) 

You'll need to update some the variables in `.env` (scripts will let you know).
</details>

You'll need access to a bundler like [Stackup](https://stackup.sh/) to submit a `userop` with `paymasterAndData`.

### Other areas to explore

* Add a flag to check for `initCode` in a `userOp`. Could only pay for gas if wallet already deployed, as a way to limiting gas costs.
* Entrypoint 0.7 and beyond are extending storage access rules. Could support additional logic like checking for `proposal` state. Only allow if `active`.

## 1. Paymaster for `delegate(address)` call

This paymaster covers the gas cost of [`delegate(address)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/utils/Votes.sol#L134) function used by ERC20 tokens. This function usually needs to be called before an owner can vote in their respective DAO. For example, Uniswap DAO is managed by UNI token holders. Those token holders can either delegate to themselves or delegate to another wallet address to vote on their behalf. That [`delegate`](https://etherscan.io/token/0x1f9840a85d5af5bf1d1762f925bdaddc4201f984#writeContract#F2) function call could be paid for by this Paymaster.

Code: [PaymasterDelegateERC20.sol](https://github.com/meliopolis/governance-paymaster/blob/main/src/PaymasterDelegateERC20.sol)

### Calldata

Sample calldata required by this Paymaster:
```solidity
    /**
     * Ex: ERC20 Delegate call. Total 196 bytes
     *  0x
     *  b61d27f6 "execute" hash
     *  0000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc4201f984 ex: ERC20 address
     *  0000000000000000000000000000000000000000000000000000000000000000 value
     *  0000000000000000000000000000000000000000000000000000000000000060 data1
     *  0000000000000000000000000000000000000000000000000000000000000024 data2
     *  5c19a95c "delegate" hash
     *  000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676 delegatee
     *  00000000000000000000000000000000000000000000000000000000 filler
     */
```

* At initialization, Paymaster is deployed for a specific ERC20Token which is then required in every calldata (ERC20 Address above) for validation to pass. 

* We check the `calldata` length and ensure that it calls `delegate(address)` function and only that function. 

* One of the features of ERC20 Token standard is that `delegate` function can be called even when token balance is zero. This is a problem as it can mean that anyone can arbitrary call the Paymaster to pay for their `delegate` transaction but it has no useful value to the token ecosystem. Thus, we check the user's balance before validating and only approve if balance is above 0. (And this is within the Storage Access Rules).

### Other Considerations

* What if the user calls the Paymaster again **immediately** after a successful delegation? This Paymaster records any successful transaction in its own storage but it doesn't know how long it's been since the last transaction (no access to `block.timestamp` in `_validatePaymasterUserOp`). So, it will approve the next request and set the `validAfter` to be 90 days away from the last successful action. (90 days is a modifiable setting in the Paymaster, even after deployment). It's up to the Bundler whether they decide to keep the transaction for that period or discard it given the future date.

* In some circumstances, we also set a `validUntil` to be `validAfter + 30 minutes`. This is not possible to set in a user's first request to use the Paymaster, as the Paymaster has no access to `block.timestamp`. But, once we have a `validAfter` value, we can set `validUntil` as well.

* What if a user repeatedly calls the Paymaster to delegate in a short period? We require a minimum waiting period (set to 90 days by default). Someone could continue receiving appropriate validation from the Paymaster for infinite transactions but in theory, the bundlers should prevent more than one to be used in any minimum waiting period window. For example, if someone generated 100 calls to `delegate(address)` from the same sender after an initial one. The Paymaster will return valid for all of them but only one will be able to go through, as the rest will fail during the on-chain validation step.

* What if someone spams the Paymaster with valid calldata length and ERC20 Token address but nonsensical data? ERC20 Balance check should fail in that case and the Bundler will reject transaction during its simulation.

### Example Transactions & Gas Usage

Deployed at: [0x5faEe2339C65944935DeFd85492948ea6079c745](https://sepolia.etherscan.io/address/0x5faEe2339C65944935DeFd85492948ea6079c745)

We compare calling the `delegate(address)` function from various different wallets.

| Wallet | Paymaster | Sample Txn | Gas Used |
| ------ | --------- | ---------- | -------- |
| EOA | - | [Txn](https://sepolia.etherscan.io/tx/0x891fd130f3dfe25e868077bd1b8f7b485c332953bbab81652b62797c7eb070aa) | 95,737 |
| AA - already deployed | None | [Txn](https://sepolia.etherscan.io/tx/0xb8eecd6f492c453e4a6ec3da20e90a3a3c8464c0a06a9e47d6bf298ea40409c4) | 167,689 |
| AA - not deployed | None | [Txn](https://sepolia.etherscan.io/tx/0xe0b8e862a01ee660a021bfc9f7b1bbd99cf8700c3a3325d4292dc2135eafa62f) | 452,501 |
| AA - already deployed | `PaymasterDelegateERC20` | [Txn](https://sepolia.etherscan.io/tx/0xb5fa82c780ac5236782f88ec9cdb80731cdf1e8c67414a10d45ce77ad77d2fc5) | 187,815 |
| AA - not deployed | `PaymasterDelegateERC20` | [Txn](https://sepolia.etherscan.io/tx/0x853dbded6e5c77617044fa5b79bf585272b869f9a59ec6373fed1e35f4fc2f1e) | 472,650 |

As you can see, gas usage of AA wallet vs EOA is quite high but the Paymaster itself is a pretty minimal increase in gas usage.

## 2. Paymaster for `castVote(uint256,uint8)` call

This Paymaster only pays for the `castVote` call. This call is typically used by on-chain governance systems to record a vote. 

Code: [PaymasterCastVote.sol](https://github.com/meliopolis/governance-paymaster/blob/main/src/PaymasterCastVote.sol)

### Calldata

Sample calldata required by this Paymaster:
```solidity
    /**
     * Ex: GovernorBravo castVote. Total 228 bytes
     * 0x
     * b61d27f6 "execute" hash
     * 000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3 "governorBravoAddress"
     * 0000000000000000000000000000000000000000000000000000000000000000 value
     * 0000000000000000000000000000000000000000000000000000000000000060 data1
     * 0000000000000000000000000000000000000000000000000000000000000044 data2
     * 56781388 "castVote" hash
     * 0000000000000000000000000000000000000000000000000000000000000034 proposalId
     * 0000000000000000000000000000000000000000000000000000000000000001 support
     * 00000000000000000000000000000000000000000000000000000000 filler
     */
```

* At initialization, Paymaster is deployed for a specific `GovernorBravo` address and an ERC20 token associated with that governor, which is then required in every calldata for validation to pass. 

* We check the `calldata` length and ensure that it calls `castVote(uint256, uint8)` function and only that function. 

### Other considerations

* What if someone spams the Paymaster with valid calldata length and `GovernorBravo` address but repetitive or nonsensical data? We are still conducting an ERC20 Balance check as well as the Governor itself will only allow each holder to vote once.

### Example Transactions & Gas Usage

Deployed at: [0x6d1915457789DdA5A0f32D006edC7Bf0cdB3f746](https://sepolia.etherscan.io/address/0x6d1915457789DdA5A0f32D006edC7Bf0cdB3f746).

We compare calling the `castVote(uint256,uint8)` function from various different wallets.

| Wallet | Paymaster | Sample Txn | Gas Used |
| ------ | --------- | ---------- | -------- |
| EOA | - | [Txn](https://sepolia.etherscan.io/tx/0x1f4c1d59d921fc9c8de19ca34d2b8ca7b6a743d6f9eabee067f26aec2a72baf8) | 76,042 |
| AA - already deployed | None | [Txn](https://sepolia.etherscan.io/tx/0xcfdf92f39f85d95b23a54d5071a9d34652fa212af8dd10eb6019458f9562c0fa) | 162,656[!!] |
| AA - already deployed | `PaymasterCastVote` | [Txn](https://sepolia.etherscan.io/tx/0x3ea7fc022afc6e28facbc4d4f3efda34bb9de041e1cf1e2daf74720e2b31ab7f) | 160,655 |
| AA - not deployed | `PaymasterCastVote` | [Txn](https://sepolia.etherscan.io/tx/0xf9c687f43bf6c30fc54e5c1c3c101c9ecfa7ecf82500c36309f940036681435b) | 472,650 |

[!!]: Counterintuitive that a transaction without Paymaster is more gas. We believe this is due to an extra transfer of ETH when no Paymaster is used.

## 3. Paymaster for `delegate(...)` or `castVote(...)` calls

This paymaster combines functionality of the above two paymasters into a single contract. It can support either `delegate(...)` or `castVote(...)` call. 

Code: [PaymasterDelegateAndCastVote.sol](https://github.com/meliopolis/governance-paymaster/blob/main/src/PaymasterDelegateAndCastVote.sol)

### Calldata

Same as the calldatas mentioned above. It can accept either of them - branching based on the length. 196 bytes for a `delegate` call and 228 bytes for a `castVote` call.  

### Other considerations

* What if the user calls this Paymaster again **immediately**? We implement logic to handle multiple `delegate` call (as described above). For `castVote`, this isn't an issue (as described above as well).

* We also set `validUntil` and `validAfter` in both scenarios, recording when the last `delegate` action was taken. This is useful as someone could drain the paymaster by calling the `delegate` action repeatedly (which isn't a risk with `castVote`).

### Example Transactions & Gas Usage

Deployed at: [0x2cEa8A3135A1eF6E5Dc42E094f043a9Bc4D27bC5](https://sepolia.etherscan.io/address/0x2cEa8A3135A1eF6E5Dc42E094f043a9Bc4D27bC5).

| Wallet | Paymaster | Governor | Sample Txn | Gas Used |
| ------ | --------- | -------- | ---------- | -------- |
| AA - already deployed | `PaymasterDelegateAndCastVote` | [`GovernorBravo`](https://sepolia.etherscan.io/address/0xfd145be4af08fc07bce4feb6ebbaefae8b69cbf5) | [Txn](https://sepolia.etherscan.io/tx/0x9d037f2a60ca643db97b44bb18976b539ec7f46db43e77d41201db306e13f48e) | 161,482 |
| AA - already deployed | `PaymasterDelegateAndCastVote` | [`OZGovernor`](https://sepolia.etherscan.io/address/0x71b27a1e1175B1ad0165b16cd7A608B670988CF0) | [Txn](https://sepolia.etherscan.io/tx/0xd5b25c13eafb8e9c984b7f4a48c5aa683632c41c66f060031aedbb907a709e2e) | 149,262 |
We expect the gas usage of this paymaster to be similar to the above two paymasters.


## Usage

### Build

```shell
$ forge build
```

### Test and Coverage
Check out `tests/`. We have 100% test coverage of all the Paymasters in this repo. 

```shell
$ forge test
```

```shell
$ forge coverage --report summary
```

### Deploy

Copy `.env.example` to `.env` and update all the variables with your details: `PRIVATE_KEY`, `PUBLIC_KEY`, `ETHERSCAN_API_KEY` and `${chainName}_RPC_URL`.

This will also `deposit` and `stake` ETH with `Entrypoint`. Ensure that you have enough ETH in the account listed in `.env`.

```shell
$ source .env
$ forge script DeployAndSetupScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --verify -vv --skip test --broadcast
```

### Abandon

When you are done with a paymaster, it's useful to withdraw the remaining ETH from Entrypoint.

Update `PAYMASTER` variable with the deployed paymaster's address in `.env`. Then, run:

```shell
$ forge script AbandonScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --skip test --broadcast 
```

## Questions/Comments

You are welcome to open Issues for any comments or reach us on [Twitter/X](https://twitter.com/aseemsood_).