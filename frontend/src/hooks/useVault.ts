'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useAccount, useChainId } from 'wagmi';
import { CONTRACTS } from '@/config/wagmi';
import { VAULT_ABI, ERC20_ABI } from '@/config/abis';
import { parseUnits, formatUnits } from 'viem';

export function useVaultContract() {
  const chainId = useChainId();
  const contracts = CONTRACTS[chainId as keyof typeof CONTRACTS];
  
  return {
    address: contracts?.vault as `0x${string}`,
    abi: VAULT_ABI,
  };
}

export function useUserPositions() {
  const { address } = useAccount();
  const { address: vaultAddress, abi } = useVaultContract();

  const { data: positionIds, isLoading, refetch } = useReadContract({
    address: vaultAddress,
    abi,
    functionName: 'getUserPositions',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address && !!vaultAddress,
    },
  });

  return {
    positionIds: positionIds as bigint[] | undefined,
    isLoading,
    refetch,
  };
}

export function usePosition(positionId: bigint | undefined) {
  const { address: vaultAddress, abi } = useVaultContract();

  const { data: position, isLoading } = useReadContract({
    address: vaultAddress,
    abi,
    functionName: 'getPosition',
    args: positionId !== undefined ? [positionId] : undefined,
    query: {
      enabled: positionId !== undefined && !!vaultAddress,
    },
  });

  const { data: healthFactor } = useReadContract({
    address: vaultAddress,
    abi,
    functionName: 'getHealthFactor',
    args: positionId !== undefined ? [positionId] : undefined,
    query: {
      enabled: positionId !== undefined && !!vaultAddress,
    },
  });

  const { data: pnlData } = useReadContract({
    address: vaultAddress,
    abi,
    functionName: 'getPositionPnL',
    args: positionId !== undefined ? [positionId] : undefined,
    query: {
      enabled: positionId !== undefined && !!vaultAddress,
    },
  });

  return {
    position: position as {
      user: `0x${string}`;
      asset: `0x${string}`;
      depositAmount: bigint;
      leverageMultiplier: bigint;
      totalExposure: bigint;
      borrowedAmount: bigint;
      entryPrice: bigint;
      entryTimestamp: bigint;
      isActive: boolean;
    } | undefined,
    healthFactor: healthFactor as bigint | undefined,
    pnl: pnlData as [bigint, bigint] | undefined,
    isLoading,
  };
}

export function useOpenPosition() {
  const { address: vaultAddress, abi } = useVaultContract();
  const chainId = useChainId();
  const contracts = CONTRACTS[chainId as keyof typeof CONTRACTS];

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const openPosition = async (
    asset: `0x${string}`,
    amount: string,
    leverage: number
  ) => {
    const amountWei = parseUnits(amount, 18);
    const leverageBps = BigInt(leverage * 10000);

    writeContract({
      address: vaultAddress,
      abi,
      functionName: 'openPosition',
      args: [asset, amountWei, leverageBps],
    });
  };

  return {
    openPosition,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

export function useClosePosition() {
  const { address: vaultAddress, abi } = useVaultContract();

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const closePosition = async (positionId: bigint) => {
    writeContract({
      address: vaultAddress,
      abi,
      functionName: 'closePosition',
      args: [positionId],
    });
  };

  return {
    closePosition,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

export function useAddCollateral() {
  const { address: vaultAddress, abi } = useVaultContract();

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const addCollateral = async (positionId: bigint, amount: string) => {
    const amountWei = parseUnits(amount, 18);

    writeContract({
      address: vaultAddress,
      abi,
      functionName: 'addCollateral',
      args: [positionId, amountWei],
    });
  };

  return {
    addCollateral,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  };
}

export function useApproveToken(tokenAddress: `0x${string}`) {
  const { address: vaultAddress } = useVaultContract();

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
      args: [vaultAddress, amountWei],
    });
  };

  const approveMax = async () => {
    writeContract({
      address: tokenAddress,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [vaultAddress, BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')],
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

export function useTokenBalance(tokenAddress: `0x${string}`) {
  const { address } = useAccount();

  const { data: balance, isLoading, refetch } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address && !!tokenAddress,
    },
  });

  return {
    balance: balance as bigint | undefined,
    formatted: balance ? formatUnits(balance as bigint, 18) : '0',
    isLoading,
    refetch,
  };
}

export function useTokenAllowance(tokenAddress: `0x${string}`) {
  const { address } = useAccount();
  const { address: vaultAddress } = useVaultContract();

  const { data: allowance, isLoading, refetch } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address && vaultAddress ? [address, vaultAddress] : undefined,
    query: {
      enabled: !!address && !!tokenAddress && !!vaultAddress,
    },
  });

  return {
    allowance: allowance as bigint | undefined,
    isLoading,
    refetch,
  };
}
