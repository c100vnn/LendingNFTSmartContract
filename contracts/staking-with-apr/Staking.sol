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
    IERC20 public mainToken;
    event StakeUpdate(
        address account,
        uint256 packageId,
        uint256 timestamp,
        uint256 amount,
        uint256 totalProfit
    );
    event StakeReleased(
        address account,
        uint256 packageId,
        uint256 timestamp,
        uint256 amount,
        uint256 totalProfit
    );
    struct StakePackage {
        uint256 rate;
        uint256 minStaking;
        uint256 lockDays;
    }
    struct StakingInfo {
        //uint256 packageId;
        uint256 startTime;
        uint256 timePoint;
        uint256 amount;
        uint256 totalProfit;
    }
    uint256 totalStake = 0;
    uint256 maxStake = 7000000000000000000000000;
    StakePackage[] public stakePackages;
    mapping(address => mapping(uint256 => StakingInfo)) public stakes;

    /**
     * @dev Initialize
     * @notice This is the initialize function, run on deploy event
     * @param _tokenAddr    address of main token
     */
    constructor(address _tokenAddr) {
        mainToken = IERC20(_tokenAddr);

        // add free-time staking package
        StakePackage memory pk;
        pk.rate = 137;
        pk.minStaking = 500 * 10**decimals();
        pk.lockDays = 5;
        stakePackages.push(pk);
    }

    function getAprOfPackage(uint256 _packageId) public view returns (uint256) {
        return stakePackages[_packageId].rate.mul(365);
    }

    function setReserve(address _reserveAddress) public onlyOwner {
        reserve = Reserve(_reserveAddress);
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    /**
     * @dev Add new staking package
     * @notice New package will be pushed to the end of StakingPackages
     * @param _rate a
     * @param _minStaking      a
     * @param _lockDays       a
     */
    function addStakePackage(
        uint256 _rate,
        uint256 _minStaking,
        uint256 _lockDays
    ) public onlyOwner {
        require(_rate > 0, 'Invalid package rate');
        stakePackages.push(StakePackage(_rate, _minStaking, _lockDays));
    }

    function removeStakePackage(uint256 _packageId) public onlyOwner {
        require(stakePackages[_packageId].rate > 0, 'Invalid package ID');
        stakePackages[_packageId].rate = 0;
    }

    function updateStakePackage(
        uint256 _packageId,
        uint256 _newRate,
        uint256 _newMinStaking,
        uint256 _newLockDays
    ) public onlyOwner {
        require(stakePackages[_packageId].rate > 0, 'Invalid package ID');
        require(_newRate > 0, 'Invalid package rate');
        stakePackages[_packageId].rate = _newRate;
        stakePackages[_packageId].minStaking = _newMinStaking;
        stakePackages[_packageId].lockDays = _newLockDays;
    }

    function getStakePackages() public view returns (StakePackage[] memory) {
        return stakePackages;
    }

    function setMaxStake(uint256 _amount) public onlyOwner {
        require(_amount > totalStake);
        maxStake = _amount;
    }

    function stake(uint256 _amount, uint256 _packageId) public {
        // validate available package and approved amount
        require(stakePackages[_packageId].rate > 0, 'Invalid package');
        require(
            mainToken.allowance(msg.sender, address(this)) >= _amount,
            'Insufficient balance'
        );
        require(totalStake.add(_amount) <= maxStake);
        require(_amount >= stakePackages[_packageId].minStaking);
        // transfer token to this staking contract
        mainToken.transferFrom(msg.sender, address(this), _amount);
        //StakingInfo memory stakingInfo = stakes[msg.sender][_packageId];
        if (stakes[msg.sender][_packageId].amount > 0) {
            uint256 profit = (
                block
                    .timestamp
                    .sub(stakes[msg.sender][_packageId].timePoint)
                    .div(86400)
                    .mul(stakePackages[_packageId].rate)
            ).mul(stakes[msg.sender][_packageId].amount).div(100000);
            stakes[msg.sender][_packageId].totalProfit = stakes[msg.sender][
                _packageId
            ].totalProfit.add(profit);
        } else {
            stakes[msg.sender][_packageId].startTime = block.timestamp;
        }
        stakes[msg.sender][_packageId].timePoint = block.timestamp;

        stakes[msg.sender][_packageId].amount = stakes[msg.sender][_packageId]
            .amount
            .add(_amount);
        totalStake = totalStake.add((_amount));
        emit StakeUpdate(
            msg.sender,
            _packageId,
            block.timestamp,
            _amount,
            stakes[msg.sender][_packageId].totalProfit
        );
    }

    function unStake(uint256 _packageId) public {
        // validate available package and approved amount
        require(stakes[msg.sender][_packageId].amount > 0, 'stake invalid');
        require(
            block.timestamp.sub(stakes[msg.sender][_packageId].timePoint) >
                stakePackages[_packageId].lockDays.mul(86400),
            'not reach lock time'
        );
        require(stakePackages[_packageId].rate > 0, 'Invalid package');
        require(stakes[msg.sender][_packageId].timePoint > 0);
        uint256 profit = (
            block
                .timestamp
                .sub(stakes[msg.sender][_packageId].timePoint)
                .div(86400)
                .mul(stakePackages[_packageId].rate)
        ).mul(stakes[msg.sender][_packageId].amount).div(100000);
        uint256 totalProfit = stakes[msg.sender][_packageId].totalProfit.add(
            profit
        );
        uint256 stakeAmount = stakes[msg.sender][_packageId].amount;
        stakes[msg.sender][_packageId].startTime = 0;
        stakes[msg.sender][_packageId].totalProfit = 0;
        stakes[msg.sender][_packageId].amount = 0;
        stakes[msg.sender][_packageId].timePoint = 0;

        mainToken.transfer(msg.sender, stakeAmount);
        reserve.distributeProfit(msg.sender, totalProfit);
        emit StakeReleased(
            msg.sender,
            _packageId,
            block.timestamp,
            stakeAmount,
            totalProfit
        );
    }

    function calculateMyProfit(uint256 _packageId)
        public
        view
        returns (uint256)
    {
        require(stakePackages[_packageId].rate > 0, 'Invalid package ID');
        require(block.timestamp !=stakes[msg.sender][_packageId].timePoint, 'Invalid stake');
        uint256 profit = (
            block
                .timestamp
                .sub(stakes[msg.sender][_packageId].timePoint)
                .div(86400)
                .mul(stakePackages[_packageId].rate)
        ).mul(stakes[msg.sender][_packageId].amount).div(100000);
        return stakes[msg.sender][_packageId].totalProfit.add(profit);
    }
}
