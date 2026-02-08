'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useAccount, useChainId } from 'wagmi';
import { CONTRACTS } from '@/config/wagmi';
import { STAKING_ABI, LVG_TOKEN_ABI, ERC20_ABI } from '@/config/abis';
import { parseUnits, formatUnits } from 'viem';

export function useStakingContract() {
  const chainId = useChainId();
  const contracts = CONTRACTS[chainId as keyof typeof CONTRACTS];
  
  return {
    address: contracts?.lvgStaking as `0x${string}`,
    abi: STAKING_ABI,
  };
}

export function useLVGToken() {
  const chainId = useChainId();
  const contracts = CONTRACTS[chainId as keyof typeof CONTRACTS];
  
  return {
    address: contracts?.lvgToken as `0x${string}`,
    abi: LVG_TOKEN_ABI,
  };
}

export function useStakingStats() {
  const { address: stakingAddress, abi } = useStakingContract();

  const { data: totalStaked } = useReadContract({
    address: stakingAddress,
    abi,
    functionName: 'totalStaked',
    query: { enabled: !!stakingAddress },
  });

  return {
    totalStaked: totalStaked as bigint | undefined,
    formatted: totalStaked ? formatUnits(totalStaked as bigint, 18) : '0',
  };
}

export function useUserStaking() {
  const { address } = useAccount();
  const { address: stakingAddress, abi } = useStakingContract();

  const { data: stakedAmount, isLoading: stakedLoading, refetch: refetchStaked } = useReadContract({
    address: stakingAddress,
    abi,
    functionName: 'getStakedAmount',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!stakingAddress },
  });

  const { data: pendingRewards, isLoading: rewardsLoading, refetch: refetchRewards } = useReadContract({
    address: stakingAddress,
    abi,
    functionName: 'getPendingRewards',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!stakingAddress },
  });

  const { data: feeDiscount, isLoading: discountLoading } = useReadContract({
    address: stakingAddress,
    abi,
    functionName: 'getFeeDiscount',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!stakingAddress },
  });

  const refetch = () => {
    refetchStaked();
    refetchRewards();
  };

  return {
    stakedAmount: stakedAmount as bigint | undefined,
    pendingRewards: pendingRewards as bigint | undefined,
    feeDiscount: feeDiscount as bigint | undefined,
    formattedStaked: stakedAmount ? formatUnits(stakedAmount as bigint, 18) : '0',
    formattedRewards: pendingRewards ? formatUnits(pendingRewards as bigint, 18) : '0',
    formattedDiscount: feeDiscount ? (Number(feeDiscount) / 100).toFixed(0) : '0',
    isLoading: stakedLoading || rewardsLoading || discountLoading,
    refetch,
  };
}

export function useLVGBalance() {
  const { address } = useAccount();
  const { address: tokenAddress, abi } = useLVGToken();

  const { data: balance, isLoading, refetch } = useReadContract({
    address: tokenAddress,
    abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!tokenAddress },
  });

  return {
    balance: balance as bigint | undefined,
    formatted: balance ? formatUnits(balance as bigint, 18) : '0',
    isLoading,
    refetch,
  };
}

export function useStake() {
  const { address: stakingAddress, abi } = useStakingContract();

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const stake = async (amount: string) => {
    const amountWei = parseUnits(amount, 18);

    writeContract({
      address: stakingAddress,
      abi,
      functionName: 'stake',
      args: [amountWei],
    });
  };

  return {
    stake,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

export function useUnstake() {
  const { address: stakingAddress, abi } = useStakingContract();

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const unstake = async (amount: string) => {
    const amountWei = parseUnits(amount, 18);

    writeContract({
      address: stakingAddress,
      abi,
      functionName: 'unstake',
      args: [amountWei],
    });
  };

  return {
    unstake,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

export function useClaimRewards() {
  const { address: stakingAddress, abi } = useStakingContract();

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const claimRewards = async () => {
    writeContract({
      address: stakingAddress,
      abi,
      functionName: 'claimRewards',
      args: [],
    });
  };

  return {
    claimRewards,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

export function useApproveLVG() {
  const { address: tokenAddress } = useLVGToken();
  const { address: stakingAddress } = useStakingContract();

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const approve = async (amount: string) => {
    const amountWei = parseUnits(amount, 18);

    writeContract({
      address: tokenAddress,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [stakingAddress, amountWei],
    });
  };

  const approveMax = async () => {
    writeContract({
      address: tokenAddress,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [stakingAddress, BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')],
    });
  };

  return {
    approve,
    approveMax,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}
