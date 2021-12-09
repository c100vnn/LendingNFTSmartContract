// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

contract RewardPool is Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    uint256 minAmount = 600000000000000000000;
    IERC20 public mainToken;
    address public stakeAddress;
    event WithdrawRequested(
        uint256 id,
        address user,
        uint256 amount,
        uint256 timestamp
    );
    event RewardDistributed(
        uint256 id,
        address user,
        uint256 amount,
        uint256 timestamp
    );
    struct WithdrawTx {
        uint256 id;
        address user;
        uint256 amount;
        uint256 timestamp;
        bool isWithdrawn;
        bool isRejected;
    }
    mapping(uint256 => WithdrawTx) public withdraws;
    mapping(address => uint256) public lastWithdraw;

    constructor(address _mainToken) {
        mainToken = IERC20(_mainToken);
    }

    function getBalanceOfRewardPool() public view onlyOwner returns (uint256) {
        return mainToken.balanceOf(address(this));
    }

    function requestWithdraw(uint256 _amount) public {
        require((block.timestamp - lastWithdraw[msg.sender]) > 86400);
        require(_amount > minAmount);
        uint256 id = _itemIds.current();
        withdraws[id] = WithdrawTx(
            id,
            msg.sender,
            _amount,
            block.timestamp,
            false,
            false
        );
        lastWithdraw[msg.sender] = block.timestamp;
        emit WithdrawRequested(id, msg.sender, _amount, block.timestamp);
        _itemIds.increment();
    }

    //1->5 là : 42%, 32%, 22%, 12%, 2%
    function distributeReward(uint256 _id, address _user) public onlyOwner {
        uint256 timeDuration = block.timestamp - lastWithdraw[_user];
        uint256 amount = withdraws[_id].amount;
        require(timeDuration > 86400);
        require(amount > minAmount);
        uint256 feeRate = 2;
        if (timeDuration > 432000) {
            feeRate = 12;
        } else if (timeDuration > 345600) {
            feeRate = 12;
        } else if (timeDuration > 259200) {
            feeRate = 22;
        } else if (timeDuration > 172800) {
            feeRate = 32;
        } else if (timeDuration > 86400) {
            feeRate = 42;
        }
        uint256 fee = amount.mul(feeRate).div(100);
        uint256 reward = amount.sub(fee);
        require(reward > getBalanceOfRewardPool());
        mainToken.transfer(_user, reward);
        withdraws[_id].isWithdrawn = true;
        emit RewardDistributed(_id, msg.sender, reward, block.timestamp);
    }
}
