// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ILayerZeroEndpointV2, MessagingParams, MessagingReceipt, MessagingFee, Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { ILVGTokenOFT, SendParam, OFTLimit, OFTReceipt, OFTFeeDetail } from "./interfaces/ILVGTokenOFT.sol";

/**
 * @title LVGTokenOFT
 * @notice LayerZero V2 OFT implementation for the LVG (Leveraged) token
 * @dev Custom OFT implementation compatible with LayerZero V2 protocol
 * 
 * Architecture:
 * - On source chain: tokens are burned via _debit()
 * - On destination chain: equivalent tokens are minted via _credit()
 * - No wrapped tokens or liquidity pools needed
 * - Same contract deployed across all supported chains
 * 
 * Security Features:
 * - Minter role for authorized bridge/reward contracts
 * - Rate limiting per destination chain
 * - Max supply cap enforcement
 * - Owner-controlled peer configuration
 * 
 * LayerZero V2 Compatibility:
 * - Uses uint32 endpoint IDs (not V1's uint16 chain IDs)
 * - Implements OApp pattern for cross-chain messaging
 * - Compatible with OFT message codec for interoperability
 */
contract LVGTokenOFT is ERC20, Ownable, ILVGTokenOFT {
    // ============ Constants ============

    /// @notice Maximum total supply: 1 billion tokens
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    /// @notice OFT message types
    uint16 public constant SEND = 1;
    uint16 public constant SEND_AND_CALL = 2;

    /// @notice Shared decimals for cross-chain transfers (6 decimals = max ~18T tokens)
    uint8 public constant SHARED_DECIMALS = 6;

    /// @notice Decimal conversion rate (10^(18-6) = 10^12)
    uint256 public constant DECIMAL_CONVERSION_RATE = 10 ** 12;

    // ============ Immutables ============

    /// @notice LayerZero V2 endpoint
    ILayerZeroEndpointV2 public immutable endpoint;

    // ============ State Variables ============

    /// @notice Mapping of authorized minter addresses
    mapping(address => bool) private _minters;

    /// @notice Trusted peer contracts on other chains (eid => peer address as bytes32)
    mapping(uint32 => bytes32) public peers;

    /// @notice Rate limit configurations per destination chain
    mapping(uint32 => RateLimit) private _rateLimits;

    /// @notice Enforced options per endpoint and message type
    mapping(uint32 => mapping(uint16 => bytes)) public enforcedOptions;

    // ============ Events ============

    /// @notice Emitted when a peer is set for an endpoint
    event PeerSet(uint32 indexed eid, bytes32 peer);

    /// @notice Emitted when tokens are sent cross-chain
    event OFTSent(
        bytes32 indexed guid,
        uint32 dstEid,
        address indexed fromAddress,
        uint256 amountSentLD,
        uint256 amountReceivedLD
    );

    /// @notice Emitted when tokens are received from another chain
    event OFTReceived(
        bytes32 indexed guid,
        uint32 srcEid,
        address indexed toAddress,
        uint256 amountReceivedLD
    );

    // ============ Errors ============

    /// @notice Invalid LayerZero endpoint
    error InvalidEndpoint();

    /// @notice No peer configured for endpoint
    error NoPeer(uint32 eid);

    /// @notice Caller is not the LayerZero endpoint
    error OnlyEndpoint();

    /// @notice Message sender is not a trusted peer
    error OnlyPeer(uint32 eid, bytes32 sender);

    /// @notice Slippage exceeded during conversion
    error SlippageExceeded(uint256 amountLD, uint256 minAmountLD);

    // ============ Constructor ============

    /**
     * @notice Deploy the LVGTokenOFT contract
     * @param _lzEndpoint The LayerZero V2 endpoint address for this chain
     * @param _initialMint Initial mint amount for deployer (0 for non-origin chains)
     */
    constructor(
        address _lzEndpoint,
        uint256 _initialMint
    ) ERC20("Leveraged", "LVG") Ownable(msg.sender) {
        if (_lzEndpoint == address(0)) revert InvalidEndpoint();
        endpoint = ILayerZeroEndpointV2(_lzEndpoint);

        // Set delegate for endpoint configuration
        endpoint.setDelegate(msg.sender);

        // Mint initial supply if specified (only on origin chain)
        if (_initialMint > 0) {
            if (_initialMint > MAX_SUPPLY) revert ExceedsMaxSupply();
            _mint(msg.sender, _initialMint);
        }
    }

    // ============ Modifiers ============

    modifier onlyMinter() {
        if (!_minters[msg.sender]) revert NotMinter();
        _;
    }

    // ============ IOFT Implementation ============

    /**
     * @notice Get OFT version information
     */
    function oftVersion() external pure returns (bytes4 interfaceId, uint64 version) {
        return (type(ILVGTokenOFT).interfaceId, 1);
    }

    /**
     * @notice Get token address (self for OFT)
     */
    function token() external view returns (address) {
        return address(this);
    }

    /**
     * @notice OFT does not require approval (it IS the token)
     */
    function approvalRequired() external pure returns (bool) {
        return false;
    }

    /**
     * @notice Get shared decimals
     */
    function sharedDecimals() external pure returns (uint8) {
        return SHARED_DECIMALS;
    }

    /**
     * @notice Quote OFT transfer details
     */
    function quoteOFT(
        SendParam calldata _sendParam
    ) external view returns (OFTLimit memory, OFTFeeDetail[] memory, OFTReceipt memory) {
        OFTLimit memory limit = OFTLimit({
            minAmountLD: DECIMAL_CONVERSION_RATE, // Minimum 1 unit in shared decimals
            maxAmountLD: totalSupply()
        });

        OFTFeeDetail[] memory feeDetails = new OFTFeeDetail[](0);

        (uint256 amountSentLD, uint256 amountReceivedLD) = _debitView(
            _sendParam.amountLD,
            _sendParam.minAmountLD,
            _sendParam.dstEid
        );

        OFTReceipt memory receipt = OFTReceipt({
            amountSentLD: amountSentLD,
            amountReceivedLD: amountReceivedLD
        });

        return (limit, feeDetails, receipt);
    }

    /**
     * @notice Quote messaging fee for send
     */
    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory) {
        (, uint256 amountReceivedLD) = _debitView(
            _sendParam.amountLD,
            _sendParam.minAmountLD,
            _sendParam.dstEid
        );

        (bytes memory message, bytes memory options) = _buildMsgAndOptions(_sendParam, amountReceivedLD);

        MessagingParams memory params = MessagingParams({
            dstEid: _sendParam.dstEid,
            receiver: _getPeerOrRevert(_sendParam.dstEid),
            message: message,
            options: options,
            payInLzToken: _payInLzToken
        });

        return endpoint.quote(params, address(this));
    }

    /**
     * @notice Send tokens to another chain
     */
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        // Check rate limit
        _checkRateLimit(_sendParam.dstEid, _sendParam.amountLD);

        // Debit tokens (burn)
        (uint256 amountSentLD, uint256 amountReceivedLD) = _debit(
            msg.sender,
            _sendParam.amountLD,
            _sendParam.minAmountLD,
            _sendParam.dstEid
        );

        // Build message
        (bytes memory message, bytes memory options) = _buildMsgAndOptions(_sendParam, amountReceivedLD);

        // Send via LayerZero
        MessagingParams memory params = MessagingParams({
            dstEid: _sendParam.dstEid,
            receiver: _getPeerOrRevert(_sendParam.dstEid),
            message: message,
            options: options,
            payInLzToken: _fee.lzTokenFee > 0
        });

        msgReceipt = endpoint.send{ value: msg.value }(params, _refundAddress);
        oftReceipt = OFTReceipt(amountSentLD, amountReceivedLD);

        emit OFTSent(msgReceipt.guid, _sendParam.dstEid, msg.sender, amountSentLD, amountReceivedLD);
    }

    /**
     * @notice Receive message from LayerZero endpoint
     * @dev Called by LayerZero endpoint when message arrives
     */
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) external payable {
        // Verify caller is endpoint
        if (msg.sender != address(endpoint)) revert OnlyEndpoint();

        // Verify sender is trusted peer
        bytes32 peer = peers[_origin.srcEid];
        if (peer == bytes32(0) || peer != _origin.sender) {
            revert OnlyPeer(_origin.srcEid, _origin.sender);
        }

        // Decode message
        (bytes32 toBytes32, uint64 amountSD) = _decodeMessage(_message);
        address toAddress = address(uint160(uint256(toBytes32)));

        // Convert to local decimals and credit
        uint256 amountLD = _toLD(amountSD);
        uint256 amountReceived = _credit(toAddress, amountLD, _origin.srcEid);

        emit OFTReceived(_guid, _origin.srcEid, toAddress, amountReceived);
    }

    /**
     * @notice Check if endpoint can deliver message
     */
    function allowInitializePath(Origin calldata _origin) external view returns (bool) {
        return peers[_origin.srcEid] == _origin.sender;
    }

    /**
     * @notice Get next expected nonce (not used in V2)
     */
    function nextNonce(uint32 /*_srcEid*/, bytes32 /*_sender*/) external pure returns (uint64) {
        return 0; // V2 handles nonces internally
    }

    // ============ Peer Management ============

    /**
     * @notice Set trusted peer for an endpoint
     * @param _eid The endpoint ID
     * @param _peer The peer address as bytes32
     */
    function setPeer(uint32 _eid, bytes32 _peer) external onlyOwner {
        peers[_eid] = _peer;
        emit PeerSet(_eid, _peer);
    }

    /**
     * @notice Set peer using regular address (convenience for EVM chains)
     */
    function setPeerAddress(uint32 _eid, address _peer) external onlyOwner {
        peers[_eid] = bytes32(uint256(uint160(_peer)));
        emit PeerSet(_eid, bytes32(uint256(uint160(_peer))));
    }

    // ============ Minter Functions ============

    /**
     * @inheritdoc ILVGTokenOFT
     */
    function isMinter(address account) external view returns (bool) {
        return _minters[account];
    }

    /**
     * @inheritdoc ILVGTokenOFT
     */
    function setMinter(address minter, bool status) external onlyOwner {
        _minters[minter] = status;
        emit MinterUpdated(minter, status);
    }

    /**
     * @inheritdoc ILVGTokenOFT
     */
    function mint(address to, uint256 amount) external onlyMinter {
        if (to == address(0)) revert InvalidRecipient();
        if (amount == 0) revert ZeroAmount();
        if (totalSupply() + amount > MAX_SUPPLY) revert ExceedsMaxSupply();
        
        _mint(to, amount);
        emit TokensMinted(to, amount, msg.sender);
    }

    // ============ Burn Functions ============

    /**
     * @inheritdoc ILVGTokenOFT
     */
    function burn(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @inheritdoc ILVGTokenOFT
     */
    function burnFrom(address from, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }

    // ============ Rate Limiting ============

    /**
     * @inheritdoc ILVGTokenOFT
     */
    function setRateLimit(uint32 eid, uint256 limit, uint256 window) external onlyOwner {
        _rateLimits[eid] = RateLimit({
            limit: limit,
            window: window,
            currentAmount: 0,
            windowStart: block.timestamp
        });
        emit RateLimitUpdated(eid, limit, window);
    }

    /**
     * @inheritdoc ILVGTokenOFT
     */
    function getRateLimit(uint32 eid) external view returns (
        uint256 limit,
        uint256 window,
        uint256 currentAmount,
        uint256 windowStart
    ) {
        RateLimit storage rl = _rateLimits[eid];
        return (rl.limit, rl.window, rl.currentAmount, rl.windowStart);
    }

    /**
     * @inheritdoc ILVGTokenOFT
     */
    function availableRateLimit(uint32 eid) external view returns (uint256 available) {
        RateLimit storage rl = _rateLimits[eid];
        
        if (rl.limit == 0) return type(uint256).max;
        
        if (block.timestamp >= rl.windowStart + rl.window) {
            return rl.limit;
        }
        
        if (rl.currentAmount >= rl.limit) return 0;
        return rl.limit - rl.currentAmount;
    }

    function _checkRateLimit(uint32 eid, uint256 amount) internal {
        RateLimit storage rl = _rateLimits[eid];
        
        if (rl.limit == 0) return;
        
        if (block.timestamp >= rl.windowStart + rl.window) {
            rl.windowStart = block.timestamp;
            rl.currentAmount = 0;
        }
        
        if (rl.currentAmount + amount > rl.limit) {
            revert RateLimitExceeded(eid, amount, rl.limit - rl.currentAmount);
        }
        
        rl.currentAmount += amount;
    }

    // ============ View Functions ============

    /**
     * @inheritdoc ILVGTokenOFT
     */
    function getEndpointIds() external pure returns (
        uint32 bsc,
        uint32 arbitrum,
        uint32 base,
        uint32 polygon,
        uint32 optimism,
        uint32 ethereum
    ) {
        return (
            30102,  // BSC
            30110,  // Arbitrum
            30184,  // Base
            30109,  // Polygon
            30111,  // Optimism
            30101   // Ethereum
        );
    }

    /**
     * @notice Check if a peer is configured for an endpoint
     */
    function hasPeer(uint32 eid) external view returns (bool) {
        return peers[eid] != bytes32(0);
    }

    /**
     * @notice Get peer address as regular address (for EVM chains)
     */
    function getPeerAddress(uint32 eid) external view returns (address) {
        return address(uint160(uint256(peers[eid])));
    }

    // ============ Internal Functions ============

    function _getPeerOrRevert(uint32 _eid) internal view returns (bytes32) {
        bytes32 peer = peers[_eid];
        if (peer == bytes32(0)) revert NoPeer(_eid);
        return peer;
    }

    function _debitView(
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 /*_dstEid*/
    ) internal pure returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        // Remove dust
        amountSentLD = (_amountLD / DECIMAL_CONVERSION_RATE) * DECIMAL_CONVERSION_RATE;
        amountReceivedLD = amountSentLD;

        if (amountReceivedLD < _minAmountLD) {
            revert SlippageExceeded(amountReceivedLD, _minAmountLD);
        }
    }

    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        _burn(_from, amountSentLD);
    }

    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    ) internal returns (uint256 amountReceivedLD) {
        if (totalSupply() + _amountLD > MAX_SUPPLY) revert ExceedsMaxSupply();
        
        if (_to == address(0)) _to = address(0xdead);
        _mint(_to, _amountLD);
        return _amountLD;
    }

    function _toSD(uint256 _amountLD) internal pure returns (uint64) {
        return uint64(_amountLD / DECIMAL_CONVERSION_RATE);
    }

    function _toLD(uint64 _amountSD) internal pure returns (uint256) {
        return uint256(_amountSD) * DECIMAL_CONVERSION_RATE;
    }

    function _buildMsgAndOptions(
        SendParam calldata _sendParam,
        uint256 _amountLD
    ) internal view returns (bytes memory message, bytes memory options) {
        bool hasCompose = _sendParam.composeMsg.length > 0;
        
        // Encode message: recipient (bytes32) + amount in shared decimals (uint64) + optional compose
        if (hasCompose) {
            message = abi.encodePacked(_sendParam.to, _toSD(_amountLD), _sendParam.composeMsg);
        } else {
            message = abi.encodePacked(_sendParam.to, _toSD(_amountLD));
        }

        // Use provided options or enforced options
        uint16 msgType = hasCompose ? SEND_AND_CALL : SEND;
        bytes memory enforced = enforcedOptions[_sendParam.dstEid][msgType];
        
        if (_sendParam.extraOptions.length > 0) {
            options = _sendParam.extraOptions;
        } else if (enforced.length > 0) {
            options = enforced;
        } else {
            // Default options: 200k gas
            options = abi.encodePacked(uint16(1), uint256(200000));
        }
    }

    function _decodeMessage(bytes calldata _message) internal pure returns (bytes32 to, uint64 amountSD) {
        to = bytes32(_message[0:32]);
        amountSD = uint64(bytes8(_message[32:40]));
    }

    // ============ Admin Functions ============

    /**
     * @notice Set enforced options for a destination/message type
     */
    function setEnforcedOptions(uint32 _eid, uint16 _msgType, bytes calldata _options) external onlyOwner {
        enforcedOptions[_eid][_msgType] = _options;
    }

    /**
     * @notice Update endpoint delegate
     */
    function setDelegate(address _delegate) external onlyOwner {
        endpoint.setDelegate(_delegate);
    }

    // ============ Convenience Functions ============

    /**
     * @notice Simplified send function
     */
    function sendTokens(
        uint32 dstEid,
        address to,
        uint256 amount
    ) external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        // Check rate limit
        _checkRateLimit(dstEid, amount);

        // Debit tokens (burn)
        (uint256 amountSentLD, uint256 amountReceivedLD) = _debit(
            msg.sender,
            amount,
            (amount * 99) / 100, // 1% slippage
            dstEid
        );

        // Build message directly (simplified - no compose)
        bytes memory message = abi.encodePacked(
            bytes32(uint256(uint160(to))),
            _toSD(amountReceivedLD)
        );

        // Default options: 200k gas
        bytes memory options = abi.encodePacked(uint16(1), uint256(200000));

        // Send via LayerZero
        MessagingParams memory params = MessagingParams({
            dstEid: dstEid,
            receiver: _getPeerOrRevert(dstEid),
            message: message,
            options: options,
            payInLzToken: false
        });

        msgReceipt = endpoint.send{ value: msg.value }(params, msg.sender);
        oftReceipt = OFTReceipt(amountSentLD, amountReceivedLD);

        emit OFTSent(msgReceipt.guid, dstEid, msg.sender, amountSentLD, amountReceivedLD);
    }

    /**
     * @notice Quote fee for simplified send
     */
    function quoteSendTokens(
        uint32 dstEid,
        address to,
        uint256 amount
    ) external view returns (uint256 nativeFee) {
        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(to))),
            amountLD: amount,
            minAmountLD: (amount * 99) / 100,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });

        MessagingFee memory fee = this.quoteSend(sendParam, false);
        return fee.nativeFee;
    }
}
