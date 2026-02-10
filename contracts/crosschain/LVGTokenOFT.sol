// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LVGTokenOFT
 * @notice LayerZero OFT-compatible LVG token for cross-chain transfers
 * @dev Implements OFT standard for seamless multi-chain deployment
 * 
 * OFT Architecture:
 * - Tokens are burned on source chain
 * - Equivalent tokens are minted on destination chain
 * - No wrapped tokens or liquidity pools needed
 * - Same contract address recommended across all chains
 */
contract LVGTokenOFT is ERC20Permit, Ownable {
    
    // ============ LayerZero Integration ============
    
    /// @notice LayerZero endpoint for cross-chain messaging
    address public lzEndpoint;
    
    /// @notice Trusted remote contracts on other chains
    mapping(uint16 => bytes) public trustedRemotes;
    
    /// @notice Minimum gas for cross-chain execution
    mapping(uint16 => uint256) public minDstGasLookup;
    
    /// @notice Use custom adapter params
    bool public useCustomAdapterParams;
    
    // ============ Token Config ============
    
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion
    
    /// @notice Addresses allowed to mint (bridge contracts)
    mapping(address => bool) public minters;
    
    // ============ Events ============
    
    event SendToChain(uint16 indexed dstChainId, address indexed from, bytes indexed toAddress, uint256 amount);
    event ReceiveFromChain(uint16 indexed srcChainId, address indexed to, uint256 amount);
    event SetTrustedRemote(uint16 indexed remoteChainId, bytes path);
    event SetMinDstGas(uint16 indexed dstChainId, uint256 minDstGas);
    event MinterUpdated(address indexed minter, bool status);
    
    // ============ Errors ============
    
    error NotMinter();
    error InvalidEndpoint();
    error ChainNotSupported();
    error InsufficientGas();
    error InvalidPayload();
    error ExceedsMaxSupply();
    
    // ============ Modifiers ============
    
    modifier onlyMinter() {
        if (!minters[msg.sender]) revert NotMinter();
        _;
    }
    
    // ============ Constructor ============
    
    constructor(
        address _lzEndpoint,
        uint256 _initialSupply
    ) ERC20("LEVERAGED", "LVG") ERC20Permit("LEVERAGED") Ownable(msg.sender) {
        if (_lzEndpoint == address(0)) revert InvalidEndpoint();
        
        lzEndpoint = _lzEndpoint;
        
        // Mint initial supply to deployer
        if (_initialSupply > 0) {
            _mint(msg.sender, _initialSupply);
        }
    }
    
    // ============ Cross-Chain Functions ============
    
    /**
     * @notice Send tokens to another chain
     * @param _dstChainId LayerZero destination chain ID
     * @param _toAddress Recipient address on destination chain
     * @param _amount Amount of tokens to send
     * @param _refundAddress Address to refund excess gas
     * @param _zroPaymentAddress ZRO token payment address (or address(0))
     * @param _adapterParams Custom adapter parameters
     */
    function sendFrom(
        address _from,
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint256 _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) external payable virtual {
        _send(_from, _dstChainId, _toAddress, _amount, _refundAddress, _zroPaymentAddress, _adapterParams);
    }
    
    /**
     * @notice Simplified send function
     */
    function send(
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint256 _amount
    ) external payable {
        _send(msg.sender, _dstChainId, _toAddress, _amount, payable(msg.sender), address(0), bytes(""));
    }
    
    /**
     * @notice Internal send implementation
     */
    function _send(
        address _from,
        uint16 _dstChainId,
        bytes memory _toAddress,
        uint256 _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) internal virtual {
        // Verify destination chain is configured
        bytes memory trustedRemote = trustedRemotes[_dstChainId];
        if (trustedRemote.length == 0) revert ChainNotSupported();
        
        // Check adapter params if custom params required
        if (useCustomAdapterParams) {
            if (_adapterParams.length == 0) revert InsufficientGas();
        } else {
            // Use default adapter params
            uint256 minGas = minDstGasLookup[_dstChainId];
            if (minGas == 0) minGas = 200000; // Default
            _adapterParams = abi.encodePacked(uint16(1), minGas);
        }
        
        // Burn tokens from sender
        _burn(_from, _amount);
        
        // Encode payload
        bytes memory payload = abi.encode(_toAddress, _amount);
        
        // Send via LayerZero
        // Note: In production, this would call lzEndpoint.send()
        // For now, we emit the event for testing
        emit SendToChain(_dstChainId, _from, _toAddress, _amount);
        
        // Actual LayerZero call would be:
        // ILayerZeroEndpoint(lzEndpoint).send{value: msg.value}(
        //     _dstChainId,
        //     trustedRemote,
        //     payload,
        //     _refundAddress,
        //     _zroPaymentAddress,
        //     _adapterParams
        // );
    }
    
    /**
     * @notice Receive tokens from another chain (called by LayerZero)
     * @dev Only callable by the LayerZero endpoint
     */
    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external virtual {
        // Verify caller is LayerZero endpoint
        if (msg.sender != lzEndpoint) revert InvalidEndpoint();
        
        // Verify source is trusted
        bytes memory trustedRemote = trustedRemotes[_srcChainId];
        if (keccak256(_srcAddress) != keccak256(trustedRemote)) revert ChainNotSupported();
        
        // Decode payload
        (bytes memory toAddressBytes, uint256 amount) = abi.decode(_payload, (bytes, uint256));
        address toAddress;
        assembly {
            toAddress := mload(add(toAddressBytes, 20))
        }
        
        // Mint tokens to recipient
        _mint(toAddress, amount);
        
        emit ReceiveFromChain(_srcChainId, toAddress, amount);
    }
    
    // ============ Estimate Functions ============
    
    /**
     * @notice Estimate fee for cross-chain transfer
     */
    function estimateSendFee(
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint256 _amount,
        bool _useZro,
        bytes calldata _adapterParams
    ) external view returns (uint256 nativeFee, uint256 zroFee) {
        bytes memory payload = abi.encode(_toAddress, _amount);
        
        // In production, would call:
        // return ILayerZeroEndpoint(lzEndpoint).estimateFees(
        //     _dstChainId,
        //     address(this),
        //     payload,
        //     _useZro,
        //     _adapterParams
        // );
        
        // Mock estimate for testing
        return (0.001 ether, 0);
    }
    
    // ============ Minting Functions ============
    
    /**
     * @notice Mint tokens (only for bridge contracts)
     */
    function mint(address _to, uint256 _amount) external onlyMinter {
        if (totalSupply() + _amount > MAX_SUPPLY) revert ExceedsMaxSupply();
        _mint(_to, _amount);
    }
    
    /**
     * @notice Burn tokens
     */
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Set trusted remote contract for a chain
     */
    function setTrustedRemote(uint16 _remoteChainId, bytes calldata _path) external onlyOwner {
        trustedRemotes[_remoteChainId] = _path;
        emit SetTrustedRemote(_remoteChainId, _path);
    }
    
    /**
     * @notice Set minimum gas for destination chain
     */
    function setMinDstGas(uint16 _dstChainId, uint256 _minDstGas) external onlyOwner {
        minDstGasLookup[_dstChainId] = _minDstGas;
        emit SetMinDstGas(_dstChainId, _minDstGas);
    }
    
    /**
     * @notice Update minter status
     */
    function setMinter(address _minter, bool _status) external onlyOwner {
        minters[_minter] = _status;
        emit MinterUpdated(_minter, _status);
    }
    
    /**
     * @notice Set LayerZero endpoint
     */
    function setLzEndpoint(address _lzEndpoint) external onlyOwner {
        if (_lzEndpoint == address(0)) revert InvalidEndpoint();
        lzEndpoint = _lzEndpoint;
    }
    
    /**
     * @notice Toggle custom adapter params requirement
     */
    function setUseCustomAdapterParams(bool _useCustom) external onlyOwner {
        useCustomAdapterParams = _useCustom;
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Check if chain is supported
     */
    function isTrustedRemote(uint16 _remoteChainId) external view returns (bool) {
        return trustedRemotes[_remoteChainId].length > 0;
    }
    
    /**
     * @notice Get chain IDs for common networks
     */
    function getChainIds() external pure returns (
        uint16 bsc,
        uint16 arbitrum,
        uint16 base,
        uint16 polygon,
        uint16 optimism
    ) {
        return (
            102,  // BSC
            110,  // Arbitrum
            184,  // Base
            109,  // Polygon
            111   // Optimism
        );
    }
}

// ============ Interfaces ============

interface ILayerZeroEndpoint {
    function send(
        uint16 _dstChainId,
        bytes calldata _destination,
        bytes calldata _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) external payable;
    
    function estimateFees(
        uint16 _dstChainId,
        address _userApplication,
        bytes calldata _payload,
        bool _payInZRO,
        bytes calldata _adapterParam
    ) external view returns (uint256 nativeFee, uint256 zroFee);
}
