//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

abstract contract TokenInfo is ERC20, ERC20Burnable {
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}