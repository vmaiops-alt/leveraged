// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestUSDT is ERC20, Ownable {
    constructor() ERC20("Test USDT", "USDT") Ownable(msg.sender) {
        // Mint 1M to deployer initially
        _mint(msg.sender, 1_000_000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
