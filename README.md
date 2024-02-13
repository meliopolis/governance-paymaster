## Governance Paymaster

** This work was funded by the Ethereum Foundation **

This repository contains Paymasters that operate fully onchain, meaning there is no centralized backend service to determine whether a transaction should be paid for by the Paymaster (and then the service provides the signature to be included in the `userop`).

Instead, these Paymasters are purpose built to only pay for specific actions on chain and they determine whether to pay for those actions with logic *completely on-chain*.

## Paymasters

1. `PaymasterDelegateERC20.sol`: Paymaster that covers the gas cost of `delegate(address)` function used by ERC20 tokens before an owner can vote in their respective DAO. For example, Uniswap DAO is managed by UNI token holders. Those token holders can either vote themselves (by self-delegating) or delegate to another wallet address to vote on their behalf. That `delegate` function call is paid for by this Paymaster.

## Usage

### Build

```shell
$ forge build
```

### Test

We use the `--via-ir` flag to avoid `stack too deep` errors.

```shell
$ forge test --via-ir
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```


### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```


