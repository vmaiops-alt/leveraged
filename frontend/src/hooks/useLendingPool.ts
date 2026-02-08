'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useAccount, useChainId } from 'wagmi';
import { CONTRACTS } from '@/config/wagmi';
import { LENDING_POOL_ABI, ERC20_ABI } from '@/config/abis';
import { parseUnits, formatUnits } from 'viem';

export function useLendingPoolContract() {
  const chainId = useChainId();
  const contracts = CONTRACTS[chainId as keyof typeof CONTRACTS];
  
  return {
    address: contracts?.lendingPool as `0x${string}`,
    abi: LENDING_POOL_ABI,
  };
}

export function useLendingPoolStats() {
  const { address: poolAddress, abi } = useLendingPoolContract();

  const { data: totalDeposits } = useReadContract({
    address: poolAddress,
    abi,
    functionName: 'getTotalDeposits',
    query: { enabled: !!poolAddress },
  });

  const { data: totalBorrowed } = useReadContract({
    address: poolAddress,
    abi,
    functionName: 'getTotalBorrowed',
    query: { enabled: !!poolAddress },
  });

  const { data: utilization } = useReadContract({
    address: poolAddress,
    abi,
    functionName: 'getUtilizationRate',
    query: { enabled: !!poolAddress },
  });

  const { data: apy } = useReadContract({
    address: poolAddress,
    abi,
    functionName: 'getCurrentAPY',
    query: { enabled: !!poolAddress },
  });

  return {
    totalDeposits: totalDeposits as bigint | undefined,
    totalBorrowed: totalBorrowed as bigint | undefined,
    utilization: utilization as bigint | undefined,
    apy: apy as bigint | undefined,
    formattedDeposits: totalDeposits ? formatUnits(totalDeposits as bigint, 18) : '0',
    formattedBorrowed: totalBorrowed ? formatUnits(totalBorrowed as bigint, 18) : '0',
    formattedUtilization: utilization ? (Number(utilization) / 100).toFixed(2) : '0',
    formattedAPY: apy ? (Number(apy) / 100).toFixed(2) : '0',
  };
}

export function useUserDeposit() {
  const { address } = useAccount();
  const { address: poolAddress, abi } = useLendingPoolContract();

  const { data: depositedAmount, isLoading, refetch } = useReadContract({
    address: poolAddress,
    abi,
    functionName: 'getDepositedAmount',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!poolAddress },
  });

  return {
    depositedAmount: depositedAmount as bigint | undefined,
    formatted: depositedAmount ? formatUnits(depositedAmount as bigint, 18) : '0',
    isLoading,
    refetch,
  };
}

export function useDeposit() {
  const { address: poolAddress, abi } = useLendingPoolContract();

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const deposit = async (amount: string) => {
    const amountWei = parseUnits(amount, 18);

    writeContract({
      address: poolAddress,
      abi,
      functionName: 'deposit',
      args: [amountWei],
    });
  };

  return {
    deposit,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

export function useWithdraw() {
  const { address: poolAddress, abi } = useLendingPoolContract();

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const withdraw = async (amount: string) => {
    const amountWei = parseUnits(amount, 18);

    writeContract({
      address: poolAddress,
      abi,
      functionName: 'withdraw',
      args: [amountWei],
    });
  };

  return {
    withdraw,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

export function useApproveLendingPool(tokenAddress: `0x${string}`) {
  const { address: poolAddress } = useLendingPoolContract();

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
      args: [poolAddress, amountWei],
    });
  };

  const approveMax = async () => {
    writeContract({
      address: tokenAddress,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [poolAddress, BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')],
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
