// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Rebased Airdrop Contract
 */
contract Airdrop is Ownable {
    
    IERC20 token;

    struct PaymentInfo {
      address payable payee;
      uint256 amount;
    }
    constructor(address _token)  {
        token = IERC20(_token);
    }
   
    function batchPayout(PaymentInfo[] calldata info) external onlyOwner {
        for (uint i=0; i < info.length; i++) {
            token.transfer(info[i].payee,info[i].amount);
        }
    }
    
    function transfer(address to, uint256 amount) internal {
        token.transfer(to, amount);
    }    
}