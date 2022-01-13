// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';

contract Deposit is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant PAUSER_ROLE = keccak256('PAUSER_ROLE');
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    uint256 minAmount = 100000000000000000000;
    IERC20 public mainToken;
    address public rewardAddress;
    event Deposited(
        uint256 id,
        address user,
        uint256 amount,
        uint256 timestamp
    );
    struct DepositTx {
        uint256 id;
        address user;
        uint256 amount;
        uint256 timestamp;
    }
    
   // withdraw[withdrawId] to get withdraw informations
    mapping(uint256 => DepositTx) public deposits;

    constructor(address _mainToken, address _rewardAddress) {
        rewardAddress = _rewardAddress;
        mainToken = IERC20(_mainToken);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // @notice User call a withdraw request
    /// @param _amount amount of token
    function deposit(uint256 _amount)
        public
        whenNotPaused
        nonReentrant
    {
        require(_amount >= minAmount);
        uint256 id = _itemIds.current();
        deposits[id] = DepositTx(
            id,
            msg.sender,
            _amount,
            block.timestamp
        );
        mainToken.transferFrom(msg.sender, rewardAddress, _amount);
        _itemIds.increment();
        emit Deposited(id, msg.sender, _amount, block.timestamp);
    }
}
