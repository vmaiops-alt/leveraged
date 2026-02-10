// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/**
 * @title LayerZeroConfig
 * @notice LayerZero V2 endpoint and chain configurations
 * @dev All endpoint addresses are the same for V2 (Universal Endpoint)
 * 
 * LayerZero V2 uses Endpoint IDs (EIDs) instead of chain IDs.
 * EIDs are uint32 values that uniquely identify each chain in the LayerZero network.
 */
library LayerZeroConfig {
    
    // ============ LayerZero V2 Universal Endpoint ============
    // Same address across all EVM chains
    address public constant LZ_ENDPOINT_V2 = 0x1a44076050125825900e736c501f859c50fE728c;
    
    // ============ LayerZero V2 Endpoint IDs (EIDs) ============
    // Source: https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
    
    // Mainnets
    uint32 public constant EID_BSC = 30102;
    uint32 public constant EID_ARBITRUM = 30110;
    uint32 public constant EID_BASE = 30184;
    uint32 public constant EID_ETHEREUM = 30101;
    uint32 public constant EID_POLYGON = 30109;
    uint32 public constant EID_OPTIMISM = 30111;
    uint32 public constant EID_AVALANCHE = 30106;
    
    // Testnets
    uint32 public constant EID_BSC_TESTNET = 40102;
    uint32 public constant EID_ARBITRUM_SEPOLIA = 40231;
    uint32 public constant EID_BASE_SEPOLIA = 40245;
    uint32 public constant EID_SEPOLIA = 40161;
    
    // ============ Chain Configurations ============
    
    struct ChainConfig {
        uint32 eid;
        address endpoint;
        string name;
        uint256 chainId;
    }
    
    /**
     * @notice Get BSC mainnet configuration
     */
    function getBSCConfig() internal pure returns (ChainConfig memory) {
        return ChainConfig({
            eid: EID_BSC,
            endpoint: LZ_ENDPOINT_V2,
            name: "BSC",
            chainId: 56
        });
    }
    
    /**
     * @notice Get Arbitrum mainnet configuration
     */
    function getArbitrumConfig() internal pure returns (ChainConfig memory) {
        return ChainConfig({
            eid: EID_ARBITRUM,
            endpoint: LZ_ENDPOINT_V2,
            name: "Arbitrum",
            chainId: 42161
        });
    }
    
    /**
     * @notice Get Base mainnet configuration
     */
    function getBaseConfig() internal pure returns (ChainConfig memory) {
        return ChainConfig({
            eid: EID_BASE,
            endpoint: LZ_ENDPOINT_V2,
            name: "Base",
            chainId: 8453
        });
    }
    
    /**
     * @notice Get Ethereum mainnet configuration
     */
    function getEthereumConfig() internal pure returns (ChainConfig memory) {
        return ChainConfig({
            eid: EID_ETHEREUM,
            endpoint: LZ_ENDPOINT_V2,
            name: "Ethereum",
            chainId: 1
        });
    }
    
    // ============ Gas Limits ============
    
    /// @notice Default gas limit for lzReceive on destination
    uint128 public constant DEFAULT_GAS_LIMIT = 200_000;
    
    /// @notice Gas limit for OFT send operations
    uint128 public constant OFT_SEND_GAS_LIMIT = 100_000;
    
    /// @notice Gas limit for composed messages
    uint128 public constant COMPOSED_GAS_LIMIT = 500_000;
    
    // ============ DVN Addresses (Default) ============
    // Source: https://docs.layerzero.network/v2/developers/evm/technical-reference/dvn-addresses
    
    // LayerZero Labs DVN (available on all chains)
    address public constant DVN_LZ_LABS_BSC = 0xfD6865c841c2d64565562fCc7e05e619A30615f0;
    address public constant DVN_LZ_LABS_ARBITRUM = 0x2f55C492897526677C5B68fb199ea31E2c126416;
    address public constant DVN_LZ_LABS_BASE = 0x9e059a54699a285714207b43B055483E78FAac25;
    
    // ============ Helper Functions ============
    
    /**
     * @notice Convert address to bytes32 for peer setting
     * @param _addr The address to convert
     * @return The address as bytes32
     */
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
    
    /**
     * @notice Convert bytes32 to address
     * @param _bytes The bytes32 to convert
     * @return The bytes32 as address
     */
    function bytes32ToAddress(bytes32 _bytes) internal pure returns (address) {
        return address(uint160(uint256(_bytes)));
    }
    
    /**
     * @notice Get all supported mainnet EIDs
     * @return eids Array of supported endpoint IDs
     */
    function getSupportedEids() internal pure returns (uint32[] memory eids) {
        eids = new uint32[](3);
        eids[0] = EID_BSC;
        eids[1] = EID_ARBITRUM;
        eids[2] = EID_BASE;
    }
    
    /**
     * @notice Check if EID is a supported mainnet
     * @param _eid The endpoint ID to check
     * @return True if supported
     */
    function isSupported(uint32 _eid) internal pure returns (bool) {
        return _eid == EID_BSC || _eid == EID_ARBITRUM || _eid == EID_BASE;
    }
    
    /**
     * @notice Get chain name from EID
     * @param _eid The endpoint ID
     * @return name The chain name
     */
    function getChainName(uint32 _eid) internal pure returns (string memory name) {
        if (_eid == EID_BSC) return "BSC";
        if (_eid == EID_ARBITRUM) return "Arbitrum";
        if (_eid == EID_BASE) return "Base";
        if (_eid == EID_ETHEREUM) return "Ethereum";
        if (_eid == EID_POLYGON) return "Polygon";
        if (_eid == EID_OPTIMISM) return "Optimism";
        return "Unknown";
    }
}
