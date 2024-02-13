// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Sample ERC20 token for testing
 */
contract ERC20Test is ERC20, ERC20Votes, Ownable {
    constructor() ERC20("Test Token", "TST") EIP712("Test Token", "1") Ownable(msg.sender) {}

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
