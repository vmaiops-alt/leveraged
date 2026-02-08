// Vault hooks
export {
  useVaultContract,
  useUserPositions,
  usePosition,
  useOpenPosition,
  useClosePosition,
  useAddCollateral,
  useApproveToken,
  useTokenBalance,
  useTokenAllowance,
} from './useVault';

// Lending pool hooks
export {
  useLendingPoolContract,
  useLendingPoolStats,
  useUserDeposit,
  useDeposit,
  useWithdraw,
  useApproveLendingPool,
} from './useLendingPool';

// Staking hooks
export {
  useStakingContract,
  useLVGToken,
  useStakingStats,
  useUserStaking,
  useLVGBalance,
  useStake,
  useUnstake,
  useClaimRewards,
  useApproveLVG,
} from './useStaking';
