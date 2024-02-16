## Governance Paymaster

_This work was funded by the Ethereum Foundation._

This repository contains Paymasters that operate fully on-chain, as in without requiring a centralized backend service with logic to determine whether a transaction should be covered by a Paymaster. 

One example of such a Paymaster that requires a backend service: [VerifyingPaymaster](https://github.com/eth-infinitism/account-abstraction/blob/develop/contracts/samples/VerifyingPaymaster.sol). This Paymaster's onchain logic only allows it to verify if the `UserOp.paymasterAndData` contains a valid signature, which is generated off-chain via a backend service.

The Paymasters in this repository are built to only pay for specific actions on-chain and they determine whether to pay for those actions with logic *completely on-chain*. Once deployed, they can operate without requiring any intervention (except perhaps to refill their accounts with `EntryPoint`).

### Usage

#### Build

```shell
$ forge build
```

#### Test

```shell
$ forge test
```

### Paymaster to cover gas for an ERC20 `delegate(address)` call

Code: [PaymasterDelegateERC20.sol](https://github.com/meliopolis/governance-paymaster/blob/main/src/PaymasterDelegateERC20.sol)

This paymaster covers the gas cost of [`delegate(address)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/utils/Votes.sol#L134) function used by ERC20 tokens. This function usually needs to be called before an owner can vote in their respective DAO. For example, Uniswap DAO is managed by UNI token holders. Those token holders can either delegate to themselves or delegate to another wallet address to vote on their behalf. That [`delegate`](https://etherscan.io/token/0x1f9840a85d5af5bf1d1762f925bdaddc4201f984#writeContract#F2) function call could be paid for by this Paymaster.

#### Methodology

Main challenge for a fully on-chain paymaster is to cover **only** the transactions specified and avoid getting drained through various different abuse vectors. 

Our logic requires specific calldata and our validation function checks for both the length and subsections of the calldata to ensure the call will only go to the intended ERC20token contract and only call `delegate(address)` function on that contract. 

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

#### Other Considerations

* What if the user calls the Paymaster again **immediately** after a successful delegation? The Paymaster records any successful transaction in its own storage but it doesn't know how long it's been since the last transaction (no access to `block.timestamp` in `_validatePaymasterUserOp`). So, it will approve the next request and set the `validAfter` to be 90 days away from the last successful action. (90 days is a modifiable setting in the Paymaster, even after deployment). It's up to the Bundler whether they decide to keep the transaction for that period or discard it given the future date.

* In some circumstances, we also set a `validUntil` to be `validAfter + 30 minutes`. This is not possible to set in a user's first request to use the Paymaster, as the Paymaster has no access to `block.timestamp`. But, once we have a `validAfter` value, we can set `validUntil` as well.

* What if a user repeatedly calls the Paymaster to delegate in a short period? We require a minimum waiting period (set to 90 days by default). Someone could continue receiving appropriate validation from the Paymaster for infinite transactions but in theory, the bundlers should prevent more than one to be used in any minimum waiting period window. For example, if someone generated 100 calls to `delegate(address)` from the same sender after an initial one. The Paymaster will return valid for all of them but only one will be able to go through, as the rest will fail during the on-chain validation step.

* What if someone spams the Paymaster with valid calldata length and ERC20 Token address but nonsensical data? ERC20 Balance check should fail in that case and the Bundler will reject transaction during its simulation.

* What if someone submits a transaction during high gas fees? There's a built-in `maxCost` to limit damage, also editable by the Paymaster Owner.

* What if there is a dishonest bundler who submits fake transactions? Then, (in theory), that bundler will get penalized by EntryPoint when the transaction fails during EntryPoint's simulation. TODO: this part is a little unclear to us. Need to talk to more bundlers to understand their implementation.

#### Storage access rules

One of the reasons on-chain Paymasters are challenging to build is due to strict storage access rules that prevent attacks.

This paymaster respects all the storage access rules. It only accesses ERC20 Token balance, which is allowed by the [rule #3 in the specifications](https://eips.ethereum.org/EIPS/eip-4337#storage-associated-with-an-address). Additionally, the Paymaster accesses its own storage and that requires it to stake with EntryPoint (which our deploy script handles).


#### Deploy

Copy `.env.example` to `.env` and update all the variables with your details: `PRIVATE_KEY`, `PUBLIC_KEY`, `ETHERSCAN_API_KEY` and `${chainName}_RPC_URL`.

This will also `deposit` and `stake` ETH with `Entrypoint`. Ensure that you have enough ETH in the account listed in `.env`.

```shell
$ source .env
$ forge script DeployAndSetupScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --verify -vv --skip test --broadcast
```

#### Abandon

When you are done with a paymaster, it's useful to withdraw the remaining ETH from Entrypoint.

Update `PAYMASTER` variable with the deployed paymaster's address in `.env`. Then, run:

```shell
$ forge script AbandonScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --skip test --broadcast 
```

#### Sample Transactions & Gas Usage

Sample Paymaster deployed at: [0x5faEe2339C65944935DeFd85492948ea6079c745](https://sepolia.etherscan.io/address/0x5faEe2339C65944935DeFd85492948ea6079c745)

| Wallet | Sample Txn | Gas Used |
| ------ | ---------- | -------- |
| EOA | [Txn](https://sepolia.etherscan.io/tx/0x891fd130f3dfe25e868077bd1b8f7b485c332953bbab81652b62797c7eb070aa) | 95,737 |
| AA (no Paymaster) - already deployed | [Txn](https://sepolia.etherscan.io/tx/0xb8eecd6f492c453e4a6ec3da20e90a3a3c8464c0a06a9e47d6bf298ea40409c4) | 167,689 |
| AA (no Paymaster) - not deployed | [Txn](https://sepolia.etherscan.io/tx/0xe0b8e862a01ee660a021bfc9f7b1bbd99cf8700c3a3325d4292dc2135eafa62f) | 452,501 |
| AA (with PaymasterDelegateERC20) - already deployed | [Txn](https://sepolia.etherscan.io/tx/0xb5fa82c780ac5236782f88ec9cdb80731cdf1e8c67414a10d45ce77ad77d2fc5) | 187,815 |
| AA (with PaymasterDelegateERC20) - not deployed | [Txn](https://sepolia.etherscan.io/tx/0x853dbded6e5c77617044fa5b79bf585272b869f9a59ec6373fed1e35f4fc2f1e) | 472,650 |

As you can see, gas usage of AA wallet vs EOA is quite high but the Paymaster itself is a pretty minimal increase in gas usage.

## Questions/Comments

You are welcome to open Issues for any comments or reach us on [Twitter/X](https://twitter.com/aseemsood_).