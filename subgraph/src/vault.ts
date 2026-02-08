import { BigInt, BigDecimal, Address, Bytes } from "@graphprotocol/graph-ts";
import {
  PositionOpened as PositionOpenedEvent,
  PositionClosed as PositionClosedEvent,
  PositionLiquidated as PositionLiquidatedEvent,
  CollateralAdded as CollateralAddedEvent,
} from "../generated/LeveragedVault/LeveragedVault";
import {
  Protocol,
  User,
  Position,
  Asset,
  PositionOpened,
  PositionClosed,
  PositionLiquidated,
  CollateralAddition,
  DailyStats,
  HourlyStats,
} from "../generated/schema";

const PROTOCOL_ID = "leveraged";
const ZERO_BD = BigDecimal.fromString("0");
const ZERO_BI = BigInt.fromI32(0);
const ONE_BI = BigInt.fromI32(1);
const BPS_DIVISOR = BigDecimal.fromString("10000");

function getOrCreateProtocol(): Protocol {
  let protocol = Protocol.load(PROTOCOL_ID);
  if (!protocol) {
    protocol = new Protocol(PROTOCOL_ID);
    protocol.totalValueLocked = ZERO_BD;
    protocol.totalPositions = ZERO_BI;
    protocol.totalActivePositions = ZERO_BI;
    protocol.totalFeesCollected = ZERO_BD;
    protocol.totalVolumeTraded = ZERO_BD;
    protocol.totalLiquidations = ZERO_BI;
    protocol.totalDeposited = ZERO_BD;
    protocol.totalBorrowed = ZERO_BD;
    protocol.utilizationRate = ZERO_BD;
    protocol.currentAPY = ZERO_BD;
    protocol.totalStaked = ZERO_BD;
    protocol.stakingAPR = ZERO_BD;
    protocol.createdAt = ZERO_BI;
    protocol.updatedAt = ZERO_BI;
  }
  return protocol;
}

function getOrCreateUser(address: Address): User {
  let user = User.load(address.toHexString());
  if (!user) {
    user = new User(address.toHexString());
    user.totalDeposited = ZERO_BD;
    user.totalPnL = ZERO_BD;
    user.totalFeesPaid = ZERO_BD;
    user.positionCount = ZERO_BI;
    user.activePositionCount = ZERO_BI;
    user.lendingDeposit = ZERO_BD;
    user.lendingEarnings = ZERO_BD;
    user.stakedAmount = ZERO_BD;
    user.stakingRewards = ZERO_BD;
    user.feeDiscount = ZERO_BI;
    user.createdAt = ZERO_BI;
    user.updatedAt = ZERO_BI;
  }
  return user;
}

function getOrCreateAsset(address: Address): Asset {
  let asset = Asset.load(address.toHexString());
  if (!asset) {
    asset = new Asset(address.toHexString());
    asset.symbol = "UNKNOWN";
    asset.name = "Unknown Asset";
    asset.decimals = 18;
    asset.currentPrice = ZERO_BD;
    asset.priceUpdatedAt = ZERO_BI;
    asset.totalExposure = ZERO_BD;
    asset.positionCount = ZERO_BI;
    asset.activePositionCount = ZERO_BI;
    asset.isSupported = true;
  }
  return asset;
}

function toDecimal(value: BigInt, decimals: i32 = 18): BigDecimal {
  let divisor = BigInt.fromI32(10).pow(decimals as u8).toBigDecimal();
  return value.toBigDecimal().div(divisor);
}

function getDayId(timestamp: BigInt): string {
  let dayTimestamp = timestamp.toI32() / 86400 * 86400;
  return dayTimestamp.toString();
}

function getHourId(timestamp: BigInt): string {
  let hourTimestamp = timestamp.toI32() / 3600 * 3600;
  return hourTimestamp.toString();
}

export function handlePositionOpened(event: PositionOpenedEvent): void {
  let protocol = getOrCreateProtocol();
  let user = getOrCreateUser(event.params.user);
  let asset = getOrCreateAsset(event.params.asset);
  
  // Create position
  let position = new Position(event.params.positionId.toString());
  position.user = user.id;
  position.asset = asset.id;
  position.depositAmount = toDecimal(event.params.depositAmount);
  position.leverageMultiplier = event.params.leverage;
  position.totalExposure = position.depositAmount.times(
    event.params.leverage.toBigDecimal().div(BPS_DIVISOR)
  );
  position.borrowedAmount = position.totalExposure.minus(position.depositAmount);
  position.entryPrice = toDecimal(event.params.entryPrice, 8); // Chainlink uses 8 decimals
  position.exitPrice = null;
  position.isActive = true;
  position.healthFactor = BigDecimal.fromString("999"); // Max initially
  position.currentPnL = ZERO_BD;
  position.currentPnLPercent = ZERO_BD;
  position.entryFee = position.depositAmount.times(BigDecimal.fromString("0.001")); // 0.1%
  position.exitFee = null;
  position.platformFee = null;
  position.openedAt = event.block.timestamp;
  position.closedAt = null;
  position.openTxHash = event.transaction.hash;
  position.closeTxHash = null;
  position.save();
  
  // Create event entity
  let positionOpened = new PositionOpened(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  positionOpened.position = position.id;
  positionOpened.user = user.id;
  positionOpened.asset = asset.id;
  positionOpened.depositAmount = position.depositAmount;
  positionOpened.leverage = event.params.leverage;
  positionOpened.entryPrice = position.entryPrice;
  positionOpened.timestamp = event.block.timestamp;
  positionOpened.txHash = event.transaction.hash;
  positionOpened.blockNumber = event.block.number;
  positionOpened.save();
  
  // Update user
  user.positionCount = user.positionCount.plus(ONE_BI);
  user.activePositionCount = user.activePositionCount.plus(ONE_BI);
  user.totalDeposited = user.totalDeposited.plus(position.depositAmount);
  user.totalFeesPaid = user.totalFeesPaid.plus(position.entryFee);
  user.updatedAt = event.block.timestamp;
  user.save();
  
  // Update asset
  asset.positionCount = asset.positionCount.plus(ONE_BI);
  asset.activePositionCount = asset.activePositionCount.plus(ONE_BI);
  asset.totalExposure = asset.totalExposure.plus(position.totalExposure);
  asset.save();
  
  // Update protocol
  protocol.totalPositions = protocol.totalPositions.plus(ONE_BI);
  protocol.totalActivePositions = protocol.totalActivePositions.plus(ONE_BI);
  protocol.totalValueLocked = protocol.totalValueLocked.plus(position.depositAmount);
  protocol.totalVolumeTraded = protocol.totalVolumeTraded.plus(position.totalExposure);
  protocol.totalFeesCollected = protocol.totalFeesCollected.plus(position.entryFee);
  protocol.updatedAt = event.block.timestamp;
  protocol.save();
}

export function handlePositionClosed(event: PositionClosedEvent): void {
  let position = Position.load(event.params.positionId.toString());
  if (!position) return;
  
  let protocol = getOrCreateProtocol();
  let user = User.load(position.user);
  if (!user) return;
  
  let asset = Asset.load(position.asset);
  if (!asset) return;
  
  // Update position
  position.exitPrice = toDecimal(event.params.exitPrice, 8);
  position.isActive = false;
  position.platformFee = toDecimal(event.params.platformFee);
  position.closedAt = event.block.timestamp;
  position.closeTxHash = event.transaction.hash;
  
  let valueIncrease = toDecimal(event.params.valueIncrease);
  let userPayout = toDecimal(event.params.userPayout);
  position.currentPnL = userPayout.minus(position.depositAmount);
  if (position.depositAmount.gt(ZERO_BD)) {
    position.currentPnLPercent = position.currentPnL
      .div(position.depositAmount)
      .times(BigDecimal.fromString("100"));
  }
  position.exitFee = position.platformFee;
  position.save();
  
  // Create event entity
  let positionClosed = new PositionClosed(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  positionClosed.position = position.id;
  positionClosed.user = user.id;
  positionClosed.exitPrice = position.exitPrice!;
  positionClosed.valueIncrease = valueIncrease;
  positionClosed.platformFee = position.platformFee!;
  positionClosed.userPayout = userPayout;
  positionClosed.pnl = position.currentPnL;
  positionClosed.pnlPercent = position.currentPnLPercent;
  positionClosed.timestamp = event.block.timestamp;
  positionClosed.txHash = event.transaction.hash;
  positionClosed.blockNumber = event.block.number;
  positionClosed.save();
  
  // Update user
  user.activePositionCount = user.activePositionCount.minus(ONE_BI);
  user.totalPnL = user.totalPnL.plus(position.currentPnL);
  user.totalFeesPaid = user.totalFeesPaid.plus(position.platformFee!);
  user.updatedAt = event.block.timestamp;
  user.save();
  
  // Update asset
  asset.activePositionCount = asset.activePositionCount.minus(ONE_BI);
  asset.totalExposure = asset.totalExposure.minus(position.totalExposure);
  asset.save();
  
  // Update protocol
  protocol.totalActivePositions = protocol.totalActivePositions.minus(ONE_BI);
  protocol.totalValueLocked = protocol.totalValueLocked.minus(position.depositAmount);
  protocol.totalFeesCollected = protocol.totalFeesCollected.plus(position.platformFee!);
  protocol.updatedAt = event.block.timestamp;
  protocol.save();
}

export function handlePositionLiquidated(event: PositionLiquidatedEvent): void {
  let position = Position.load(event.params.positionId.toString());
  if (!position) return;
  
  let protocol = getOrCreateProtocol();
  let user = User.load(position.user);
  if (!user) return;
  
  let asset = Asset.load(position.asset);
  if (!asset) return;
  
  // Update position
  position.exitPrice = toDecimal(event.params.exitPrice, 8);
  position.isActive = false;
  position.closedAt = event.block.timestamp;
  position.closeTxHash = event.transaction.hash;
  position.currentPnL = ZERO_BD.minus(position.depositAmount); // Full loss on liquidation
  position.currentPnLPercent = BigDecimal.fromString("-100");
  position.save();
  
  // Create event entity
  let liquidation = new PositionLiquidated(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  liquidation.position = position.id;
  liquidation.user = user.id;
  liquidation.liquidator = event.params.liquidator;
  liquidation.exitPrice = position.exitPrice!;
  liquidation.debtRepaid = position.borrowedAmount;
  liquidation.collateralSeized = position.totalExposure;
  liquidation.liquidatorBonus = position.totalExposure.times(BigDecimal.fromString("0.05")); // 5%
  liquidation.timestamp = event.block.timestamp;
  liquidation.txHash = event.transaction.hash;
  liquidation.blockNumber = event.block.number;
  liquidation.save();
  
  // Update user
  user.activePositionCount = user.activePositionCount.minus(ONE_BI);
  user.totalPnL = user.totalPnL.minus(position.depositAmount);
  user.updatedAt = event.block.timestamp;
  user.save();
  
  // Update asset
  asset.activePositionCount = asset.activePositionCount.minus(ONE_BI);
  asset.totalExposure = asset.totalExposure.minus(position.totalExposure);
  asset.save();
  
  // Update protocol
  protocol.totalActivePositions = protocol.totalActivePositions.minus(ONE_BI);
  protocol.totalValueLocked = protocol.totalValueLocked.minus(position.depositAmount);
  protocol.totalLiquidations = protocol.totalLiquidations.plus(ONE_BI);
  protocol.updatedAt = event.block.timestamp;
  protocol.save();
}

export function handleCollateralAdded(event: CollateralAddedEvent): void {
  let position = Position.load(event.params.positionId.toString());
  if (!position) return;
  
  let user = User.load(position.user);
  if (!user) return;
  
  let amount = toDecimal(event.params.amount);
  
  // Update position
  position.depositAmount = position.depositAmount.plus(amount);
  position.totalExposure = position.totalExposure.plus(amount);
  position.save();
  
  // Create event entity
  let collateralAddition = new CollateralAddition(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  collateralAddition.position = position.id;
  collateralAddition.user = user.id;
  collateralAddition.amount = amount;
  collateralAddition.newHealthFactor = position.healthFactor;
  collateralAddition.timestamp = event.block.timestamp;
  collateralAddition.txHash = event.transaction.hash;
  collateralAddition.blockNumber = event.block.number;
  collateralAddition.save();
  
  // Update user
  user.totalDeposited = user.totalDeposited.plus(amount);
  user.updatedAt = event.block.timestamp;
  user.save();
  
  // Update protocol TVL
  let protocol = getOrCreateProtocol();
  protocol.totalValueLocked = protocol.totalValueLocked.plus(amount);
  protocol.updatedAt = event.block.timestamp;
  protocol.save();
}
