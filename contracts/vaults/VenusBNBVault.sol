// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IVenus.sol";

/// @title Venus BNB Vault - Auto-compounding BNB Strategy
/// @notice Deposit BNB, earn Venus yield + auto-compound
contract VenusBNBVault is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Venus BNB market
    IVenusBNB public constant vBNB = IVenusBNB(0xA07c5b74C9B40447a954e1466938b865b6BBea36);
    IERC20 public constant XVS = IERC20(0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63);
    
    // Venus Comptroller
    IComptroller public constant comptroller = IComptroller(0xfD36E2c2a6789Db23113685031d7F16329158384);
    
    // PancakeSwap for compounding
    IPancakeRouter public constant router = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    
    // Vault state
    uint256 public totalShares;
    mapping(address => uint256) public shares;
    
    // Fees (basis points)
    uint256 public performanceFee = 500;    // 5%
    uint256 public withdrawFee = 10;         // 0.1%
    address public treasury;
    
    // Slippage protection
    uint256 public constant MIN_SLIPPAGE_BPS = 50; // 0.5% minimum
    uint256 public slippageTolerance = 100;        // 1% default
    
    // Events
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event Harvest(uint256 xvsHarvested, uint256 bnbCompounded);
    
    constructor(address _treasury) Ownable(msg.sender) {
        treasury = _treasury;
        // Approve router for XVS
        XVS.forceApprove(address(router), type(uint256).max);
    }
    
    /// @notice Deposit BNB into vault
    function deposit() external payable nonReentrant {
        require(msg.value > 0, "Amount must be > 0");
        
        uint256 sharesMinted;
        uint256 balanceBefore = balance();
        
        _depositToVenus(msg.value);
        
        if (totalShares == 0) {
            sharesMinted = msg.value;
        } else {
            sharesMinted = (msg.value * totalShares) / balanceBefore;
        }
        
        shares[msg.sender] += sharesMinted;
        totalShares += sharesMinted;
        
        emit Deposit(msg.sender, msg.value, sharesMinted);
    }
    
    /// @notice Withdraw BNB from vault
    function withdraw(uint256 _shares) external nonReentrant {
        require(_shares > 0 && _shares <= shares[msg.sender], "Invalid shares");
        
        uint256 withdrawAmount = (_shares * balance()) / totalShares;
        
        shares[msg.sender] -= _shares;
        totalShares -= _shares;
        
        // Withdraw from Venus
        _withdrawFromVenus(withdrawAmount);
        
        // Apply withdrawal fee
        uint256 fee = (withdrawAmount * withdrawFee) / 10000;
        if (fee > 0) {
            (bool sent, ) = treasury.call{value: fee}("");
            require(sent, "Fee transfer failed");
        }
        
        // Send BNB to user
        (bool success, ) = msg.sender.call{value: withdrawAmount - fee}("");
        require(success, "BNB transfer failed");
        
        emit Withdraw(msg.sender, withdrawAmount - fee, _shares);
    }
    
    /// @notice Harvest XVS rewards and compound to BNB
    function harvest() external {
        // Claim XVS
        address[] memory vTokens = new address[](1);
        vTokens[0] = address(vBNB);
        comptroller.claimVenus(address(this), vTokens);
        
        uint256 xvsBal = XVS.balanceOf(address(this));
        if (xvsBal == 0) return;
        
        // Take performance fee
        uint256 fee = (xvsBal * performanceFee) / 10000;
        if (fee > 0) {
            XVS.safeTransfer(treasury, fee);
            xvsBal -= fee;
        }
        
        // Swap XVS → BNB
        address[] memory path = new address[](2);
        path[0] = address(XVS);
        path[1] = WBNB;
        
        uint256 bnbBefore = address(this).balance;
        
        // Calculate minimum output with slippage protection
        uint256[] memory expectedAmounts = router.getAmountsOut(xvsBal, path);
        uint256 minAmountOut = (expectedAmounts[1] * (10000 - slippageTolerance)) / 10000;
        
        router.swapExactTokensForETH(
            xvsBal,
            minAmountOut,  // Slippage protected
            path,
            address(this),
            block.timestamp
        );
        
        uint256 bnbHarvested = address(this).balance - bnbBefore;
        
        // Deposit harvested BNB back to Venus
        if (bnbHarvested > 0) {
            _depositToVenus(bnbHarvested);
        }
        
        emit Harvest(xvsBal + fee, bnbHarvested);
    }
    
    /// @notice Total BNB balance in Venus
    function balance() public view returns (uint256) {
        uint256 vBNBBal = vBNB.balanceOf(address(this));
        uint256 exchangeRate = vBNB.exchangeRateStored();
        return (vBNBBal * exchangeRate) / 1e18 + address(this).balance;
    }
    
    /// @notice Get user's balance in BNB
    function balanceOf(address _user) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (shares[_user] * balance()) / totalShares;
    }
    
    /// @notice Price per share
    function pricePerShare() external view returns (uint256) {
        if (totalShares == 0) return 1e18;
        return (balance() * 1e18) / totalShares;
    }
    
    /// @notice Pending XVS rewards
    function pendingRewards() external view returns (uint256) {
        return comptroller.venusAccrued(address(this));
    }
    
    // Internal functions
    function _depositToVenus(uint256 _amount) internal {
        vBNB.mint{value: _amount}();
    }
    
    function _withdrawFromVenus(uint256 _amount) internal {
        uint256 bnbBal = address(this).balance;
        if (bnbBal < _amount) {
            vBNB.redeemUnderlying(_amount - bnbBal);
        }
    }
    
    // Admin functions
    function setFees(uint256 _performanceFee, uint256 _withdrawFee) external onlyOwner {
        require(_performanceFee <= 2000, "Max 20%");
        require(_withdrawFee <= 100, "Max 1%");
        performanceFee = _performanceFee;
        withdrawFee = _withdrawFee;
    }
    
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }
    
    function setSlippageTolerance(uint256 _slippageTolerance) external onlyOwner {
        require(_slippageTolerance >= MIN_SLIPPAGE_BPS, "Slippage too low");
        require(_slippageTolerance <= 500, "Slippage too high"); // Max 5%
        slippageTolerance = _slippageTolerance;
    }
    
    // Emergency
    function emergencyWithdraw() external onlyOwner {
        uint256 vBNBBal = vBNB.balanceOf(address(this));
        if (vBNBBal > 0) {
            vBNB.redeem(vBNBBal);
        }
    }
    
    function recoverToken(address _token) external onlyOwner {
        require(_token != address(XVS), "Use harvest for XVS");
        uint256 bal = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(owner(), bal);
    }
    
    // Receive BNB
    receive() external payable {}
}
