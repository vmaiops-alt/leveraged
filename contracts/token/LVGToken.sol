// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title LVGToken
 * @notice Leveraged Platform Governance & Utility Token
 * @dev ERC-20 with minting caps for rewards emission
 */
contract LVGToken {
    
    // ============ ERC-20 State ============
    
    string public constant name = "Leveraged";
    string public constant symbol = "LVG";
    uint8 public constant decimals = 18;
    
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    // ============ Token Distribution ============
    
    uint256 public constant MAX_SUPPLY = 100_000_000 * 1e18; // 100M tokens
    
    // Allocation percentages (of MAX_SUPPLY)
    uint256 public constant TEAM_ALLOCATION = 15_000_000 * 1e18;      // 15%
    uint256 public constant TREASURY_ALLOCATION = 20_000_000 * 1e18;  // 20%
    uint256 public constant LIQUIDITY_ALLOCATION = 10_000_000 * 1e18; // 10%
    uint256 public constant FARMING_ALLOCATION = 40_000_000 * 1e18;   // 40%
    uint256 public constant PRIVATE_SALE_ALLOCATION = 10_000_000 * 1e18; // 10%
    uint256 public constant AIRDROP_ALLOCATION = 5_000_000 * 1e18;    // 5%
    
    // ============ Minting Control ============
    
    address public owner;
    address public minter; // Staking contract can mint rewards
    
    uint256 public farmingMinted;
    uint256 public farmingStartTime;
    uint256 public constant FARMING_DURATION = 4 * 365 days; // 4 years
    
    bool public initialDistributionDone;
    
    // ============ Events ============
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event MinterSet(address indexed minter);
    event TokensBurned(address indexed from, uint256 amount);
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyMinter() {
        require(msg.sender == minter || msg.sender == owner, "Not minter");
        _;
    }
    
    // ============ Constructor ============
    
    constructor() {
        owner = msg.sender;
        farmingStartTime = block.timestamp;
    }
    
    // ============ Initial Distribution ============
    
    /**
     * @notice Perform initial token distribution
     * @param team Team wallet (with vesting)
     * @param treasury Treasury/DAO wallet
     * @param liquidity Liquidity wallet for DEX
     * @param privateSale Private sale wallet (with vesting)
     * @param airdrop Airdrop wallet
     */
    function initialDistribution(
        address team,
        address treasury,
        address liquidity,
        address privateSale,
        address airdrop
    ) external onlyOwner {
        require(!initialDistributionDone, "Already distributed");
        require(team != address(0) && treasury != address(0), "Invalid addresses");
        
        // Mint initial allocations (except farming which is minted over time)
        _mint(team, TEAM_ALLOCATION);
        _mint(treasury, TREASURY_ALLOCATION);
        _mint(liquidity, LIQUIDITY_ALLOCATION);
        _mint(privateSale, PRIVATE_SALE_ALLOCATION);
        _mint(airdrop, AIRDROP_ALLOCATION);
        
        initialDistributionDone = true;
    }
    
    // ============ Minting ============
    
    /**
     * @notice Set the minter (staking contract)
     * @param _minter The minter address
     */
    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
        emit MinterSet(_minter);
    }
    
    /**
     * @notice Mint farming rewards (capped)
     * @param to Recipient
     * @param amount Amount to mint
     */
    function mintFarmingRewards(address to, uint256 amount) external onlyMinter {
        require(farmingMinted + amount <= FARMING_ALLOCATION, "Farming cap exceeded");
        require(to != address(0), "Invalid recipient");
        
        farmingMinted += amount;
        _mint(to, amount);
    }
    
    /**
     * @notice Get remaining farming rewards
     * @return remaining Tokens that can still be minted for farming
     */
    function remainingFarmingRewards() external view returns (uint256) {
        return FARMING_ALLOCATION - farmingMinted;
    }
    
    /**
     * @notice Get farming emission rate per second
     * @return rate Tokens per second
     */
    function getFarmingEmissionRate() external view returns (uint256) {
        return FARMING_ALLOCATION / FARMING_DURATION;
    }
    
    // ============ Burning ============
    
    /**
     * @notice Burn tokens from sender
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit TokensBurned(msg.sender, amount);
        emit Transfer(msg.sender, address(0), amount);
    }
    
    /**
     * @notice Burn tokens from address (requires allowance)
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burnFrom(address from, uint256 amount) external {
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        require(balanceOf[from] >= amount, "Insufficient balance");
        
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        totalSupply -= amount;
        
        emit TokensBurned(from, amount);
        emit Transfer(from, address(0), amount);
    }
    
    // ============ ERC-20 Functions ============
    
    function transfer(address to, uint256 amount) external returns (bool) {
        return _transfer(msg.sender, to, amount);
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        return _transfer(from, to, amount);
    }
    
    // ============ Internal Functions ============
    
    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(from != address(0), "Transfer from zero");
        require(to != address(0), "Transfer to zero");
        require(balanceOf[from] >= amount, "Insufficient balance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function _mint(address to, uint256 amount) internal {
        require(totalSupply + amount <= MAX_SUPPLY, "Max supply exceeded");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}
