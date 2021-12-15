// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract Reserve is Ownable {
    IERC20 public mainToken;
    address public stakeAddress;
    constructor(address _mainToken, address _stakeAddress) {
        mainToken = IERC20(_mainToken);
        stakeAddress = _stakeAddress;
    }
    function getBalanceOfReserve() public view returns(uint256) {
       return mainToken.balanceOf(address(this));
    }
    function distributeProfit(address _recipient, uint256 _amount) public {
        require(msg.sender == stakeAddress);
        mainToken.transfer(_recipient, _amount);
    }
}
