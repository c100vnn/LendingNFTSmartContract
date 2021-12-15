// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';

contract RewardPool is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant PAUSER_ROLE = keccak256('PAUSER_ROLE');
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
    }
    
   // withdraw[withdrawId] to get withdraw informations
    mapping(uint256 => WithdrawTx) public withdraws;
    // lastWithdraw[userAddress] last withdraw distributed event
    mapping(address => uint256) public lastWithdraw;

    constructor(address _mainToken) {
        mainToken = IERC20(_mainToken);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    // @notice Get total balance of Reward pool
    function getBalanceOfRewardPool()
        public
        view
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint256)
    {
        return mainToken.balanceOf(address(this));
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // @notice User call a withdraw request
    /// @param _amount amount of token
    function requestWithdraw(uint256 _amount)
        public
        whenNotPaused
        nonReentrant
    {
        require((block.timestamp - lastWithdraw[msg.sender]) > 86400);
        require(_amount >= minAmount);
        uint256 id = _itemIds.current();
        withdraws[id] = WithdrawTx(
            id,
            msg.sender,
            _amount,
            block.timestamp,
            false
        );
        
        emit WithdrawRequested(id, msg.sender, _amount, block.timestamp);
        _itemIds.increment();
    }

    // @notice Admin distribute reward for an pending withdraw request
    // can't distribute if lastWithDraw is placed < one day
    // from day 1 to day 5, got fees: 42%, 32%, 22%, 12%, 2%
    /// @param _id amount of tokenø
    function distributeReward(uint256 _id)
        public
        whenNotPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        address user = withdraws[_id].user;
        uint256 timeDuration = withdraws[_id].timestamp - lastWithdraw[user];
        uint256 amount = withdraws[_id].amount;
        require(timeDuration > 86400 || lastWithdraw[user] == 0);
        require(amount >= minAmount);
        
        uint256 feeRate;
        if (timeDuration > 432000){  //> 5 day
            feeRate = 2;
        } else if (timeDuration > 345600 && timeDuration <= 432000) { // from day 4 to  day 5
            feeRate = 12;
        } else if (timeDuration > 259200 && timeDuration <= 345600) { // from day 3 to day 4
            feeRate = 22;
        } else if (timeDuration > 172800 && timeDuration <= 259200) { // from day 2 to day 3
            feeRate = 32;
        } else if (timeDuration > 86400 && timeDuration <= 172800) {  // from day 1 to day 2
            feeRate = 42;
        }

        uint256 fee = amount.mul(feeRate).div(100);
        uint256 reward = amount.sub(fee);
        require(reward < getBalanceOfRewardPool(), "not enough balance");
        mainToken.transfer(user, reward);
        withdraws[_id].isWithdrawn = true;
        lastWithdraw[user] = block.timestamp;
        emit RewardDistributed(_id, user, reward, block.timestamp);
    }
}
