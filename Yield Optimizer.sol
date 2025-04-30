// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title YieldOptimizer
 * @dev A simple yield optimizer that routes funds to the best yielding protocol
 * among a predetermined set of lending protocols on Core Chain.
 */
contract YieldOptimizer is Ownable(msg.sender), ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Supported lending protocols
    enum Protocol { PROTOCOL_A, PROTOCOL_B, PROTOCOL_C }
    
    // Structure for protocol yield data
    struct ProtocolData {
        address contractAddress;
        bool active;
        uint256 currentAPY; // APY represented as basis points (1% = 100)
    }
    
    // User deposit information
    struct UserDeposit {
        uint256 amount;
        Protocol currentProtocol;
        uint256 lastUpdated;
    }
    
    // Token that users can deposit (e.g., USDC)
    IERC20 public depositToken;
    
    // Protocol data
    mapping(Protocol => ProtocolData) public protocols;
    
    // User deposits
    mapping(address => UserDeposit) public userDeposits;
    
    // Total funds in the optimizer
    uint256 public totalDeposits;
    
    // Protocol with the highest current APY
    Protocol public bestProtocol;
    
    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event ProtocolUpdated(Protocol indexed protocol, uint256 newAPY);
    event FundsRebalanced(Protocol indexed oldProtocol, Protocol indexed newProtocol, uint256 amount);
    
    /**
     * @dev Constructor initializes the optimizer with supported protocols
     * @param _depositToken Address of the token users will deposit
     * @param _protocolA Address of the first lending protocol
     * @param _protocolB Address of the second lending protocol
     * @param _protocolC Address of the third lending protocol
     */
    constructor(
        address _depositToken,
        address _protocolA,
        address _protocolB,
        address _protocolC
    ) {
        depositToken = IERC20(_depositToken);
        
        // Initialize protocol data
        protocols[Protocol.PROTOCOL_A] = ProtocolData({
            contractAddress: _protocolA,
            active: true,
            currentAPY: 500 // 5% initial APY
        });
        
        protocols[Protocol.PROTOCOL_B] = ProtocolData({
            contractAddress: _protocolB,
            active: true,
            currentAPY: 450 // 4.5% initial APY
        });
        
        protocols[Protocol.PROTOCOL_C] = ProtocolData({
            contractAddress: _protocolC,
            active: true,
            currentAPY: 480 // 4.8% initial APY
        });
        
        // Initialize best protocol
        bestProtocol = Protocol.PROTOCOL_A; // Default
        _updateBestProtocol();
    }
    
    /**
     * @dev Deposit tokens into the yield optimizer
     * @param amount Amount of tokens to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot deposit zero amount");
        
        // Transfer tokens from user to contract
        depositToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update user deposit data
        UserDeposit storage userData = userDeposits[msg.sender];
        
        if (userData.amount == 0) {
            // New deposit
            userData.currentProtocol = bestProtocol;
        } else {
            // Existing user - keep their current protocol assignment
        }
        
        userData.amount += amount;
        userData.lastUpdated = block.timestamp;
        
        // Update total deposits
        totalDeposits += amount;
        
        // Note: In a real implementation, we would immediately allocate these 
        // funds to the target protocol. This is simplified for demonstration.
        
        emit Deposited(msg.sender, amount);
    }
    
    /**
     * @dev Withdraw tokens from the yield optimizer
     * @param amount Amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        UserDeposit storage userData = userDeposits[msg.sender];
        
        require(userData.amount >= amount, "Insufficient balance");
        
        // Update user deposit data
        userData.amount -= amount;
        userData.lastUpdated = block.timestamp;
        
        // Update total deposits
        totalDeposits -= amount;
        
        // Note: In a real implementation, we would need to withdraw the funds
        // from the actual protocol before sending them back to the user.
        // This is simplified for demonstration.
        
        // Transfer tokens back to user
        depositToken.safeTransfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount);
    }
    
    /**
     * @dev Update protocol APY and rebalance funds if necessary
     * @param protocol Protocol enum value to update
     * @param newAPY New APY value in basis points
     */
    function updateProtocolAPY(Protocol protocol, uint256 newAPY) external onlyOwner {
        require(protocols[protocol].active, "Protocol is not active");
        
        // Update APY for the protocol
        protocols[protocol].currentAPY = newAPY;
        
        emit ProtocolUpdated(protocol, newAPY);
        
        // Check if this changes the best protocol
        Protocol oldBest = bestProtocol;
        _updateBestProtocol();
        
        // If best protocol changed, we may want to rebalance funds
        if (oldBest != bestProtocol && totalDeposits > 0) {
            // Note: In a real implementation, this would move funds between protocols
            // This is simplified for demonstration
            emit FundsRebalanced(oldBest, bestProtocol, totalDeposits);
        }
    }
    
    /**
     * @dev Internal function to determine the best protocol based on APY
     */
    function _updateBestProtocol() internal {
        uint256 highestAPY = 0;
        
        // Check each protocol
        for (uint i = 0; i < 3; i++) {
            Protocol protocol = Protocol(i);
            ProtocolData memory protocolData = protocols[protocol];
            
            if (protocolData.active && protocolData.currentAPY > highestAPY) {
                highestAPY = protocolData.currentAPY;
                bestProtocol = protocol;
            }
        }
    }
    
    /**
     * @dev Get the current APY for a user
     * @param user Address of the user
     * @return Current APY in basis points
     */
    function getUserAPY(address user) external view returns (uint256) {
        UserDeposit memory userData = userDeposits[user];
        
        if (userData.amount == 0) {
            return 0;
        }
        
        return protocols[userData.currentProtocol].currentAPY;
    }
    
    /**
     * @dev Emergency function to recover tokens
     * @param token Address of the token to recover
     */
    function recoverTokens(address token) external onlyOwner {
        require(token != address(depositToken), "Cannot recover deposit token");
        
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        
        tokenContract.safeTransfer(owner(), balance);
    }
}
