// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IVenus.sol";

/// @title Venus Vault - Auto-compounding Venus Strategy
/// @notice Deposit tokens, earn Venus yield + auto-compound
contract VenusVault is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Tokens
    IERC20 public immutable want;           // Token users deposit (e.g., USDT)
    IVToken public immutable vToken;         // Venus vToken (e.g., vUSDT)
    IERC20 public constant XVS = IERC20(0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63);
    IERC20 public constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    
    // Venus
    IComptroller public constant comptroller = IComptroller(0xfD36E2c2a6789Db23113685031d7F16329158384);
    
    // PancakeSwap for compounding
    IPancakeRouter public constant router = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    
    // Vault state
    uint256 public totalShares;
    mapping(address => uint256) public shares;
    
    // Fees (basis points, 10000 = 100%)
    uint256 public performanceFee = 500;    // 5% of profits
    uint256 public withdrawFee = 10;         // 0.1% withdrawal fee
    address public treasury;
    
    // Events
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event Harvest(uint256 xvsHarvested, uint256 wantCompounded);
    
    constructor(
        address _want,
        address _vToken,
        address _treasury
    ) Ownable(msg.sender) {
        want = IERC20(_want);
        vToken = IVToken(_vToken);
        treasury = _treasury;
        
        // Approve Venus
        IERC20(_want).forceApprove(_vToken, type(uint256).max);
        // Approve router for XVS
        XVS.forceApprove(address(router), type(uint256).max);
    }
    
    /// @notice Deposit tokens into vault
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be > 0");
        
        uint256 sharesMinted;
        uint256 balanceBefore = balance();
        
        want.safeTransferFrom(msg.sender, address(this), _amount);
        _depositToVenus();
        
        if (totalShares == 0) {
            sharesMinted = _amount;
        } else {
            sharesMinted = (_amount * totalShares) / balanceBefore;
        }
        
        shares[msg.sender] += sharesMinted;
        totalShares += sharesMinted;
        
        emit Deposit(msg.sender, _amount, sharesMinted);
    }
    
    /// @notice Withdraw tokens from vault
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
            want.safeTransfer(treasury, fee);
        }
        
        want.safeTransfer(msg.sender, withdrawAmount - fee);
        
        emit Withdraw(msg.sender, withdrawAmount - fee, _shares);
    }
    
    /// @notice Harvest XVS rewards and compound
    function harvest() external {
        // Claim XVS
        address[] memory vTokens = new address[](1);
        vTokens[0] = address(vToken);
        comptroller.claimVenus(address(this), vTokens);
        
        uint256 xvsBal = XVS.balanceOf(address(this));
        if (xvsBal == 0) return;
        
        // Take performance fee
        uint256 fee = (xvsBal * performanceFee) / 10000;
        if (fee > 0) {
            XVS.safeTransfer(treasury, fee);
            xvsBal -= fee;
        }
        
        // Swap XVS → WBNB → want
        address[] memory path = new address[](3);
        path[0] = address(XVS);
        path[1] = address(WBNB);
        path[2] = address(want);
        
        uint256 wantBefore = want.balanceOf(address(this));
        
        router.swapExactTokensForTokens(
            xvsBal,
            0,  // Accept any amount (consider adding slippage protection)
            path,
            address(this),
            block.timestamp
        );
        
        uint256 wantHarvested = want.balanceOf(address(this)) - wantBefore;
        
        // Deposit harvested tokens back to Venus
        _depositToVenus();
        
        emit Harvest(xvsBal + fee, wantHarvested);
    }
    
    /// @notice Total balance in Venus (in want tokens)
    function balance() public view returns (uint256) {
        uint256 vTokenBal = vToken.balanceOf(address(this));
        uint256 exchangeRate = vToken.exchangeRateStored();
        return (vTokenBal * exchangeRate) / 1e18 + want.balanceOf(address(this));
    }
    
    /// @notice Get user's balance in want tokens
    function balanceOf(address _user) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (shares[_user] * balance()) / totalShares;
    }
    
    /// @notice Price per share (for APY calculation)
    function pricePerShare() external view returns (uint256) {
        if (totalShares == 0) return 1e18;
        return (balance() * 1e18) / totalShares;
    }
    
    /// @notice Pending XVS rewards
    function pendingRewards() external view returns (uint256) {
        return comptroller.venusAccrued(address(this));
    }
    
    // Internal functions
    function _depositToVenus() internal {
        uint256 wantBal = want.balanceOf(address(this));
        if (wantBal > 0) {
            vToken.mint(wantBal);
        }
    }
    
    function _withdrawFromVenus(uint256 _amount) internal {
        uint256 wantBal = want.balanceOf(address(this));
        if (wantBal < _amount) {
            vToken.redeemUnderlying(_amount - wantBal);
        }
    }
    
    // Admin functions
    function setFees(uint256 _performanceFee, uint256 _withdrawFee) external onlyOwner {
        require(_performanceFee <= 2000, "Max 20%");  // Max 20% performance fee
        require(_withdrawFee <= 100, "Max 1%");       // Max 1% withdrawal fee
        performanceFee = _performanceFee;
        withdrawFee = _withdrawFee;
    }
    
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }
    
    // Emergency functions
    function emergencyWithdraw() external onlyOwner {
        uint256 vTokenBal = vToken.balanceOf(address(this));
        if (vTokenBal > 0) {
            vToken.redeem(vTokenBal);
        }
    }
    
    function recoverToken(address _token) external onlyOwner {
        require(_token != address(want) && _token != address(vToken), "Cannot recover main tokens");
        uint256 bal = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(owner(), bal);
    }
}
