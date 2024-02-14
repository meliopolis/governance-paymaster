## Governance Paymaster

_This work was funded by the Ethereum Foundation_

This repository contains Paymasters that operate fully on-chain - without a need for a complimentary, centralized backend service with logic to determine whether a transaction should be covered by a Paymaster. For example, [VerifyingPaymaster](https://github.com/eth-infinitism/account-abstraction/blob/develop/contracts/samples/VerifyingPaymaster.sol) requires a separate backend service that checks the transaction and returns an appropriate signature that's validated on-chain by the Paymaster.

Instead, these Paymasters are built to only pay for specific actions on-chain and they determine whether to pay for those actions with logic *completely on-chain*. Once deployed, they can operate without requiring any intervention (except perhaps to refill their accounts with `EntryPoint`).

## Usage

### Build

```shell
$ forge build
```

### Test

We use the `--via-ir` flag to avoid `stack too deep` errors. Those errors are only an issue in `tests`, not in any Paymasters.

```shell
$ forge test --via-ir
```

## Paymaster to cover gas for an ERC20 `delegate(address)` call

src: [PaymasterDelegateERC20.sol](https://github.com/meliopolis/governance-paymaster/blob/main/src/PaymasterDelegateERC20.sol)

This paymaster covers the gas cost of [`delegate(address)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/utils/Votes.sol#L134) function used by ERC20 tokens. This function usually needs to be called before an owner can vote in their respective DAO. For example, Uniswap DAO is managed by UNI token holders. Those token holders can either delegate to themselves or delegate to another wallet address to vote on their behalf. That [`delegate`](https://etherscan.io/token/0x1f9840a85d5af5bf1d1762f925bdaddc4201f984#writeContract#F2) function call could be paid for by this Paymaster.

### Methodology

Main challenge for a fully on-chain paymaster is to cover **only** the transactions specified and avoid getting drained through various different abuse vectors. 

Our logic requires specific calldata and our validation function checks for both the length and subsections of the calldata to ensure the call will only go to the intended ERC20token contract and only call `delegate(address)` function on that contract. 

Sample calldata:
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

* What if the user calls the Paymaster again **immediately** after a successful delegation? The Paymaster records any successful transaction in its own storage but it doesn't know how long it's been since the last transaction (no access to `block.timestamp` in `_validatePaymasterUserOp`). So, it will approve the next request and set the `validAfter` to be 90 days away from the last successful action. (90 days is a modifiable setting in the Paymaster, even after deployment). It's up to the Bundler whether they decide to keep the transaction for that period or discard it given the future date.

* In some circumstances, we also set a `validUntil` to be `validAfter + 30 minutes`. This is not possible to set in a user's first request to use the Paymaster, as the Paymaster has no access to `block.timestamp`. But, once we have a `validAfter` value, we can set `validUntil` as well.

* Repeatedly calling the Payamaster to delegate in a short period. We require a minimum waiting period (set to 90 days by default). In theory, someone could continue receiving appropriate validation from the Paymaster for infinite transactions but in theory, the bundlers should prevent more than one to be used in any minimum waiting period window. For example, if someone generated 100 calls to `delegate(address)` from the same sender after an initial one. The Paymaster will return valid for all of them but only one will be able to go through.

* What if someone spams the Paymaster with valid calldata length and ERC20 Token address but nonsensical data. ERC20 Balance check should fail in that case and the Bundler will reject transaction during its simulation.

* What if someone submits a transaction during high gas times? There's a built-in `maxCost` to limit damage, also editable by the Paymaster Owner.

* What if there is a dishonest bundler who submits fake transactions? Then, that bundler will get penalized by EntryPoint when the transaction fails during EntryPoint's simulation. TODO: this part is a little unclear to us. Need to talk to more bundlers to understand their constraints.

### Storage access rules

One of the reasons on-chain Paymasters are challenging to build is due to strict storage access rules that prevent attacks.

This paymaster respects all the storage access rules. It only accesses ERC20 Token balance, which is allowed by the [rule #3 in the specifications](https://eips.ethereum.org/EIPS/eip-4337#storage-associated-with-an-address). Additionally, the Paymaster accesses its own storage and that requires it to stake with EntryPoint (which our deploy script handles).


### Deploy

Copy `.env.example` to `.env` and update all the variables with your details: `PRIVATE_KEY`, `PUBLIC_KEY`, `ETHERSCAN_API_KEY` and `${chainName}_RPC_URL`.

This will also `deposit` and `stake` ETH with `Entrypoint`. Ensure that you have enough ETH in the account listed in `.env`.

```shell
$ source .env
$ forge script DeployAndSetupScript --rpc-url $SEPOLIA_RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY --verify -vv --via-ir --skip test --broadcast
```

### Abandon

When you are done with a paymaster, it's useful to withdraw the remaining ETH from Entrypoint.

Update `PAYMASTER` variable with the deployed paymaster's address in `.env`. Then, run:

```shell
$ forge script AbandonScript --rpc-url $SEPOLIA_RPC_URL --broadcast --via-ir --skip test
```

### Sample Transactions & Gas Usage

Sample Paymaster deployed at: [0xEDe4aCB68C3e0fa9818F87025D513Be3Ad10826E](https://sepolia.etherscan.io/address/0xEDe4aCB68C3e0fa9818F87025D513Be3Ad10826E)

1. [Delegate call on UNI token](https://sepolia.etherscan.io/tx/0xd525d6c7a0c928b67fe3abb42be708e8598868f9e4dcbacdc6e07a4bad35cde9): This includes cost of deploying the AA wallet as well. Gas usage: 470,504.

2. [Another Delegate call on UNI token](https://sepolia.etherscan.io/tx/0x8460d71c78f24f68b8e5bc04453982b0696bd8174bb22f71eea18602f6836000): This wallet was already deployed before the Paymaster is called. Gas used: 185,705.

3. [EOA delegate](https://sepolia.etherscan.io/tx/0x891fd130f3dfe25e868077bd1b8f7b485c332953bbab81652b62797c7eb070aa): called from an EOA. Gas usage: 95,737.

One of our future tasks is to figure out how to minimize gas usage, especially when the AA wallet is already deployed.

## Questions/Comments

You are welcome to open Issues for any comments or reach us on [Twitter/X](https://twitter.com/aseemsood_).