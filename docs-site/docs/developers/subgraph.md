---
sidebar_position: 1
---
# Subgraph

Query indexed protocol data using The Graph.

## Endpoint

```
https://api.thegraph.com/subgraphs/name/leveraged-finance/leveraged-bsc
```

*Testnet: Replace with testnet subgraph URL*

## Example Queries

### Get User Positions

```graphql
query GetUserPositions($user: String!) {
  positions(where: { user: $user, isActive: true }) {
    id
    asset { symbol }
    depositAmount
    leverageMultiplier
    totalExposure
    entryPrice
    healthFactor
    currentPnL
    openedAt
  }
}
```

### Protocol Stats

```graphql
query GetProtocolStats {
  protocol(id: "leveraged") {
    totalValueLocked
    totalPositions
    totalActivePositions
    totalFeesCollected
    totalLiquidations
  }
}
```

### Recent Positions

```graphql
query RecentPositions {
  positionOpeneds(first: 10, orderBy: timestamp, orderDirection: desc) {
    position { id }
    user { id }
    asset { symbol }
    depositAmount
    leverage
    timestamp
  }
}
```

### Liquidations

```graphql
query Liquidations($from: BigInt!) {
  positionLiquidateds(where: { timestamp_gt: $from }) {
    position { id }
    user { id }
    liquidator
    debtRepaid
    collateralSeized
    timestamp
  }
}
```

### Daily Stats

```graphql
query DailyStats($days: Int!) {
  dailyStats(first: $days, orderBy: date, orderDirection: desc) {
    date
    totalVolume
    positionsOpened
    positionsClosed
    liquidations
    feesCollected
  }
}
```

## Schema

See full schema: [schema.graphql](https://github.com/leveraged-finance/leveraged/blob/main/subgraph/schema.graphql)

### Key Entities

- `Protocol` - Global stats
- `User` - User data and positions
- `Position` - Individual positions
- `Asset` - Supported assets
- `DailyStats` / `HourlyStats` - Time series data

## Using in Frontend

```typescript
import { request, gql } from 'graphql-request';

const SUBGRAPH_URL = 'https://api.thegraph.com/subgraphs/name/leveraged/bsc';

const query = gql`
  query GetPositions($user: String!) {
    positions(where: { user: $user }) {
      id
      depositAmount
      currentPnL
    }
  }
`;

const data = await request(SUBGRAPH_URL, query, { user: address });
```

## Self-Hosting

Deploy your own subgraph:

```bash
cd subgraph
npm install
graph codegen
graph build
graph deploy --studio leveraged
```
