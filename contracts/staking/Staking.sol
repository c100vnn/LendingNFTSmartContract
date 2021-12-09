// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './Reserve.sol';
contract Staking is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    Reserve public reserve; //kho tien lai
    IERC20 public mainToken; // token stake
    uint256 public rewardRate; //R
    uint256 public lastUpdateTime; //a, thoi gian cap nhat cuoi cung
    uint256 public rewardPerTokenStake; //Sigma (delta t)*R/L(t)
    mapping(address => uint256) public userRewardPerStake; //userRewardPerStake[account] =>  uint256.
    mapping(address => uint256) public userToRewards;
    uint256 totalSupply; //L(t)
    mapping(address => StakingInfo) public userToStakeInfo;

    struct StakingInfo {
        uint256 amount;
        uint256 startTime;
    }

    constructor(address _mainToken, uint256 _rewardRate) {
        mainToken = IERC20(_mainToken);
        rewardRate = _rewardRate;
    }

    function setReserve(address _reserve) public onlyOwner {
        reserve = Reserve(_reserve);
    }

    // Sigma(t) R/L
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStake;
        }
        return
            //0+t*R/L
            rewardPerTokenStake.add(
                block
                    .timestamp
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply)
            );
    }

    function calculateUserReward(address account)
        public
        view
        returns (uint256)
    {
        return
            userToStakeInfo[account]
                .amount
                .mul(rewardPerToken().sub(userRewardPerStake[account]))
                .div(1e18)
                .add(userToRewards[account]);
    }

    modifier updateReward(address account) {
        require(account != address(0));
        rewardPerTokenStake = rewardPerToken(); //+=t*R/L
        lastUpdateTime = block.timestamp;
        userToRewards[account] = calculateUserReward(account); // += amount*((t*R/L) - 0) //---((a-1))
        userRewardPerStake[account] = rewardPerTokenStake;
        _;
    }

    function addStake(uint256 _amount)
        public
        nonReentrant
        updateReward(msg.sender)
    {
        require(_amount > 0);
        totalSupply = totalSupply.add(_amount);
        mainToken.transferFrom(msg.sender, address(this), _amount);
        if (userToStakeInfo[msg.sender].amount == 0) {
            userToStakeInfo[msg.sender] = StakingInfo(_amount, block.timestamp);
        } else {
            userToStakeInfo[msg.sender].amount = userToStakeInfo[msg.sender]
                .amount
                .add(_amount);
        }
    }

    function withdrawStake(uint256 _amount)
        public
        nonReentrant
        updateReward(msg.sender)
    {
        require(_amount > 0);
        require(_amount <= userToStakeInfo[msg.sender].amount);
        totalSupply = totalSupply.sub(_amount);
        userToStakeInfo[msg.sender].amount = userToStakeInfo[msg.sender]
            .amount
            .sub(_amount);
        mainToken.transfer(msg.sender, _amount);
    }

    function claimReward() public nonReentrant updateReward(msg.sender) {
        require(userToRewards[msg.sender] > 0);
        reserve.transferToStakeContract(userToRewards[msg.sender], msg.sender);
        userToRewards[msg.sender] = 0;
    }

    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }

    function getStakeInfo(address account) external view returns (StakingInfo memory) {
        return userToStakeInfo[account];
    }
}
