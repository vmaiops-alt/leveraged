// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { MessagingReceipt, MessagingFee } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

/**
 * @dev Struct representing token parameters for the OFT send() operation.
 */
struct SendParam {
    uint32 dstEid;          // Destination endpoint ID
    bytes32 to;             // Recipient address (bytes32 for non-EVM compatibility)
    uint256 amountLD;       // Amount to send in local decimals
    uint256 minAmountLD;    // Minimum amount after dust removal (slippage protection)
    bytes extraOptions;     // Additional LayerZero options
    bytes composeMsg;       // Optional compose message for lzCompose
    bytes oftCmd;           // OFT command (unused in default implementation)
}

/**
 * @dev Struct representing OFT limit information.
 */
struct OFTLimit {
    uint256 minAmountLD;    // Minimum sendable amount
    uint256 maxAmountLD;    // Maximum sendable amount
}

/**
 * @dev Struct representing OFT receipt information.
 */
struct OFTReceipt {
    uint256 amountSentLD;       // Amount debited from sender
    uint256 amountReceivedLD;   // Amount to be credited on destination
}

/**
 * @dev Struct representing OFT fee details.
 */
struct OFTFeeDetail {
    int256 feeAmountLD;     // Fee amount in local decimals
    string description;     // Fee description
}

/**
 * @title ILVGTokenOFT
 * @notice Interface for the LVG Token OFT (Omnichain Fungible Token)
 * @dev Implements LayerZero V2 OFT standard with additional LVG-specific functionality
 */
interface ILVGTokenOFT {
    // ============ Events ============

    /// @notice Emitted when a minter's status is updated
    event MinterUpdated(address indexed minter, bool status);

    /// @notice Emitted when tokens are minted by an authorized minter
    event TokensMinted(address indexed to, uint256 amount, address indexed minter);

    /// @notice Emitted when tokens are burned
    event TokensBurned(address indexed from, uint256 amount);

    /// @notice Emitted when rate limit is updated for a chain
    event RateLimitUpdated(uint32 indexed eid, uint256 limit, uint256 window);

    // ============ Errors ============

    /// @notice Caller is not an authorized minter
    error NotMinter();

    /// @notice Minting would exceed the maximum supply
    error ExceedsMaxSupply();

    /// @notice Invalid recipient address (zero address)
    error InvalidRecipient();

    /// @notice Transfer amount exceeds rate limit
    error RateLimitExceeded(uint32 eid, uint256 amount, uint256 limit);

    /// @notice Amount must be greater than zero
    error ZeroAmount();

    // ============ Structs ============

    /// @notice Rate limit configuration for a destination chain
    struct RateLimit {
        uint256 limit;          // Maximum amount per window
        uint256 window;         // Time window in seconds
        uint256 currentAmount;  // Amount sent in current window
        uint256 windowStart;    // Start timestamp of current window
    }

    // ============ OFT Standard Functions ============

    /**
     * @notice Retrieves interfaceID and the version of the OFT
     */
    function oftVersion() external view returns (bytes4 interfaceId, uint64 version);

    /**
     * @notice Retrieves the address of the token
     */
    function token() external view returns (address);

    /**
     * @notice Whether the OFT requires approval to send
     */
    function approvalRequired() external view returns (bool);

    /**
     * @notice Get shared decimals used for cross-chain transfers
     */
    function sharedDecimals() external view returns (uint8);

    /**
     * @notice Get OFT transfer details and limits
     */
    function quoteOFT(
        SendParam calldata _sendParam
    ) external view returns (OFTLimit memory, OFTFeeDetail[] memory, OFTReceipt memory);

    /**
     * @notice Quote messaging fee for send operation
     */
    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory);

    /**
     * @notice Send tokens to another chain
     */
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory, OFTReceipt memory);

    // ============ Minter Functions ============

    /**
     * @notice Check if an address is an authorized minter
     */
    function isMinter(address account) external view returns (bool);

    /**
     * @notice Set minter status for an address
     */
    function setMinter(address minter, bool status) external;

    /**
     * @notice Mint tokens to an address (only callable by minters)
     */
    function mint(address to, uint256 amount) external;

    // ============ Burn Functions ============

    /**
     * @notice Burn tokens from the caller's balance
     */
    function burn(uint256 amount) external;

    /**
     * @notice Burn tokens from an address (requires allowance)
     */
    function burnFrom(address from, uint256 amount) external;

    // ============ View Functions ============

    /**
     * @notice Get the maximum supply cap
     */
    function MAX_SUPPLY() external view returns (uint256);

    /**
     * @notice Get the rate limit configuration for a chain
     */
    function getRateLimit(uint32 eid) external view returns (
        uint256 limit,
        uint256 window,
        uint256 currentAmount,
        uint256 windowStart
    );

    /**
     * @notice Check available rate limit for a chain
     */
    function availableRateLimit(uint32 eid) external view returns (uint256 available);

    // ============ Admin Functions ============

    /**
     * @notice Set rate limit for a destination chain
     */
    function setRateLimit(uint32 eid, uint256 limit, uint256 window) external;

    // ============ Chain ID Reference ============

    /**
     * @notice Get LayerZero V2 endpoint IDs for common networks
     */
    function getEndpointIds() external pure returns (
        uint32 bsc,
        uint32 arbitrum,
        uint32 base,
        uint32 polygon,
        uint32 optimism,
        uint32 ethereum
    );
}
