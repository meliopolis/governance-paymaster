## Governance Paymaster

** This work was funded by the Ethereum Foundation **

This repository contains Paymasters that operate fully onchain, meaning there is no centralized backend service to determine whether a transaction should be paid for by the Paymaster (and then the service provides the signature to be included in the `userop`).

Instead, these Paymasters are purpose built to only pay for specific actions on chain and they determine whether to pay for those actions with logic *completely on-chain*.

## Paymasters

1. `PaymasterDelegateERC20.sol`: Paymaster that covers the gas cost of `delegate(address)` function used by ERC20 tokens before an owner can vote in their respective DAO. For example, Uniswap DAO is managed by UNI token holders. Those token holders can either vote themselves (by self-delegating) or delegate to another wallet address to vote on their behalf. That `delegate` function call is paid for by this Paymaster.

### Considerations

Main challenge for a fully on-chain paymaster is to avoid getting drained. Our methodology requires a specific calldata and our validation function checks for both the length and tests specific sections of the calldata to ensure the call will only go to a specific ERC20token contract and only call `delegate(address)` function on that contract.

* This Paymaster only pays for delegation on one specific ERC20 Token address (which is set at initialization).

* Call data checks require that it calls `delegate(address)` function and only that function 

* Calling the Paymaster when the user may not have any ERC20 Token. We check the user's balance before validating.

* Repeatedly calling the Payamaster to delegate in a short period. We require a minimum waiting period (set to 90 days by default) and editable by Paymaster's owner.

* Since the validation function can't access `block.timestamp`, we track the last time a user successfully used the Paymaster to pay for a `delegate` call. On subsequent calls from the same user, we return `validAfter` to be the last timestamp + `minWaitTime`.

* In those circumstances, we also set a `validUntil` to be `validAfter + 30 minutes`. This is not possible to set in a user's first request to use the Paymaster, as the Paymaster has no access to `block.timestamp`.

For some attack vectors, Bundler behavior also matters. 

* If a user calls the Paymaster again **immediately** after a successful delegation, Paymaster will approve the next request and set the `validAfter` to be 90 days away. It's up to the Bundler whether they decide to keep the transaction for that period or discard it given the future date. TODO: confirm this behavior with bundlers

Other What Ifs

* What if someone spams the Paymaster with valid calldata length and ERC20 Token address but nonsensical data. ERC20 Balance check should fail in that case and the Bundler will reject transaction during its simulation.

* What if someone submits a transaction during high gas times? There's a built-in `maxCost` to limit damage, also editable by the Paymaster Owner.

* What if there is a dishonest bundler who submits fake transactions? Then, that bundler will get penalized by EntryPoint when the transaction fails during EntryPoint's simulation

### Other Notes

* Does this paymaster respect all the storage access rules? Yes! The Paymaster only accesses ERC20 Token balance, which is allowed by the (rule #3 in the specifications)[https://eips.ethereum.org/EIPS/eip-4337#storage-associated-with-an-address]. Additionally, the Paymaster accesses its own storage and that requires it to stake with EntryPoint (which our deploy script handles).

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


### Deploy

Copy `.env.example` to `.env` and update all the variables with your details: `PRIVATE_KEY`, `PUBLIC_KEY`, `ETHERSCAN_API_KEY` and `${chainID}_RPC_URL`.

```shell
$ forge script PaymasterDelegateERC20Script --rpc-url $SEPOLIA_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
```


