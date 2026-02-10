// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PrincipalToken
 * @notice ERC20 token representing the principal portion of a yield-bearing position
 * @dev PT tokens can be redeemed 1:1 for underlying at maturity
 * 
 * Pendle-style yield tokenization:
 * - User deposits yield-bearing asset (e.g., aUSDT)
 * - Receives PT (principal) + YT (yield) tokens
 * - PT trades at discount before maturity
 * - At maturity, PT = 1 underlying
 * 
 * Example:
 * - Deposit 100 aUSDT with 1 year maturity
 * - Receive 100 PT-aUSDT + 100 YT-aUSDT
 * - PT trades at ~95 USDT (implies 5% yield)
 * - At maturity: 100 PT = 100 USDT
 */
contract PrincipalToken is ERC20, ERC20Permit, Ownable {
    
    // ============ State Variables ============
    
    /// @notice The underlying asset this PT represents
    address public immutable underlying;
    
    /// @notice The yield tokenizer contract that can mint/burn
    address public tokenizer;
    
    /// @notice Maturity timestamp
    uint256 public immutable maturity;
    
    /// @notice Whether the token has matured
    bool public matured;
    
    // ============ Events ============
    
    event Matured(uint256 timestamp);
    event TokenizerUpdated(address indexed oldTokenizer, address indexed newTokenizer);
    
    // ============ Errors ============
    
    error NotTokenizer();
    error NotMatured();
    error AlreadyMatured();
    error InvalidMaturity();
    error ZeroAddress();
    
    // ============ Modifiers ============
    
    modifier onlyTokenizer() {
        if (msg.sender != tokenizer) revert NotTokenizer();
        _;
    }
    
    modifier notMatured() {
        if (matured) revert AlreadyMatured();
        _;
    }
    
    // ============ Constructor ============
    
    /**
     * @param _name Token name (e.g., "PT-aUSDT-10FEB2027")
     * @param _symbol Token symbol (e.g., "PT-aUSDT")
     * @param _underlying Underlying asset address
     * @param _maturity Maturity timestamp
     * @param _tokenizer Tokenizer contract address
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _underlying,
        uint256 _maturity,
        address _tokenizer
    ) ERC20(_name, _symbol) ERC20Permit(_name) Ownable(msg.sender) {
        if (_underlying == address(0)) revert ZeroAddress();
        if (_tokenizer == address(0)) revert ZeroAddress();
        if (_maturity <= block.timestamp) revert InvalidMaturity();
        
        underlying = _underlying;
        maturity = _maturity;
        tokenizer = _tokenizer;
    }
    
    // ============ Tokenizer Functions ============
    
    /**
     * @notice Mint PT tokens (only tokenizer)
     * @param _to Recipient address
     * @param _amount Amount to mint
     */
    function mint(address _to, uint256 _amount) external onlyTokenizer notMatured {
        _mint(_to, _amount);
    }
    
    /**
     * @notice Burn PT tokens (only tokenizer)
     * @param _from Address to burn from
     * @param _amount Amount to burn
     */
    function burn(address _from, uint256 _amount) external onlyTokenizer {
        _burn(_from, _amount);
    }
    
    // ============ Maturity Functions ============
    
    /**
     * @notice Mark token as matured (anyone can call after maturity)
     */
    function mature() external {
        if (block.timestamp < maturity) revert NotMatured();
        if (matured) revert AlreadyMatured();
        
        matured = true;
        emit Matured(block.timestamp);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Check if token has reached maturity
     */
    function isMatured() external view returns (bool) {
        return matured || block.timestamp >= maturity;
    }
    
    /**
     * @notice Time until maturity
     */
    function timeToMaturity() external view returns (uint256) {
        if (block.timestamp >= maturity) return 0;
        return maturity - block.timestamp;
    }
    
    /**
     * @notice Get implied yield based on current price
     * @param _ptPrice Current PT price in underlying terms (18 decimals)
     * @return annualizedYield Annualized yield in basis points
     */
    function getImpliedYield(uint256 _ptPrice) external view returns (uint256 annualizedYield) {
        if (block.timestamp >= maturity) return 0;
        if (_ptPrice == 0) return type(uint256).max; // Infinite yield if price is zero
        if (_ptPrice >= 1e18) return 0;
        
        uint256 timeToMat = maturity - block.timestamp;
        if (timeToMat == 0) return 0;
        
        uint256 discount = 1e18 - _ptPrice;
        
        // Annualized yield = (discount / price) * (365 days / timeToMaturity) * 10000 (bps)
        annualizedYield = (discount * 365 days * 10000) / (_ptPrice * timeToMat);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Update tokenizer address
     */
    function setTokenizer(address _newTokenizer) external onlyOwner {
        if (_newTokenizer == address(0)) revert ZeroAddress();
        
        address oldTokenizer = tokenizer;
        tokenizer = _newTokenizer;
        
        emit TokenizerUpdated(oldTokenizer, _newTokenizer);
    }
}
