// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './Reserve.sol';

contract Staking is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    Reserve public reserve;
    IERC20 public mainToken;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStake;
    mapping(address => uint256) public userRewardPerStake;
    mapping(address => uint256) public userToRewards;
    uint256 totalSupply;
    mapping(address => StakingInfo) public userToStakeInfo;

    struct StakingInfo {
        uint256 amount;
        uint256 startTime;
    }

    constructor(address _mainToken, uint256 _rewardRate) {
        mainToken = IERC20(_mainToken);
        rewardRate = _rewardRate;
    }
    function setReserve(address _reserve) public onlyOwner(){
        reserve = Reserve(_reserve);
    }
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStake;
        }
        return
            rewardPerTokenStake.add(
                block
                    .timestamp
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply)
            );
    }
    function calculateUserReward(address account) public view returns (uint256) {
        return userToStakeInfo[account].amount.mul(rewardPerToken().sub(userRewardPerStake[account])).div(1e18).div(totalSupply);
    }
    modifier updateReward(address account) {
        require(account != address(0));
        rewardPerTokenStake = rewardPerToken();
        lastUpdateTime = block.timestamp;
        userToRewards[account] = calculateUserReward(account);
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
}
