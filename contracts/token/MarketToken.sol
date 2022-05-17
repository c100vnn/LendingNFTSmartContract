//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/TokenWithdrawable.sol";
import "./utils/TokenInfo.sol";

/**
 * Market token contract - BEP20
*/
contract MarketToken is TokenWithdrawable, TokenInfo {
    constructor() ERC20("MarketToken", "MTN") {
        _mint(msg.sender, 10**9 * 10**decimals());
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        //Prohibit user to transfer to token address
        require(recipient != address(this), "Can't transfer to token address");
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
}