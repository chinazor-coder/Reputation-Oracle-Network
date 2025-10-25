# Reputation Oracle Network

A decentralized reputation system built on Stacks blockchain where validators stake tokens to provide weighted reputation assessments for any entity.

## Overview

The Reputation Oracle Network allows validators to stake STX tokens and provide reputation scores (0-100) for entities identified by unique string IDs. The system uses weighted voting based on validator stake and historical accuracy to calculate aggregate reputation scores.

## Key Features

- **Validator Staking System**: Validators must stake minimum 1 STX to participate
- **Weighted Assessments**: Validator votes are weighted by stake amount and historical accuracy
- **Query Fee Mechanism**: Users pay 0.01 STX to query reputation scores
- **Cooldown Protection**: Prevents spam queries with ~1 day cooldown per entity/user pair
- **Reputation Tracking**: Maintains validator accuracy metrics for credibility scoring
- **Dynamic Weight Calculation**: Combines stake size and assessment accuracy

## Architecture

### Data Structures

1. **Validators Map**: Stores validator information including stake, reputation score, and assessment statistics
2. **Entities Map**: Tracks aggregated reputation data for each entity
3. **Validator Assessments**: Records individual validator scores for entities
4. **Query History**: Implements cooldown mechanism for queries

### Core Functions

#### Validator Functions

- `register-validator(stake-amount)`: Register as validator with STX stake
- `submit-assessment(entity-id, score)`: Submit reputation score (0-100) for an entity
- `increase-stake(amount)`: Add more STX to validator stake
- `withdraw-stake()`: Deactivate and withdraw validator stake

#### User Functions

- `query-reputation(entity-id)`: Pay fee to get current reputation score

#### Read-Only Functions

- `get-entity-reputation(entity-id)`: View reputation without paying fee
- `get-validator-info(validator)`: Check validator statistics
- `get-validator-assessment(validator, entity-id)`: View specific validator's assessment
- `get-total-validators()`: Get count of active validators
- `get-protocol-treasury()`: View accumulated protocol fees

## Usage Examples

### Register as Validator

```clarity
(contract-call? .reputation-oracle register-validator u1000000)
```

### Submit Assessment

```clarity
(contract-call? .reputation-oracle submit-assessment "company-abc-2025" u85)
```

### Query Reputation

```clarity
(contract-call? .reputation-oracle query-reputation "company-abc-2025")
;; Returns: {reputation: u85, assessments: u1, last-updated: u12345}
```

### Check Reputation (Free)

```clarity
(contract-call? .reputation-oracle get-entity-reputation "company-abc-2025")
```

## Constants

- `min-validator-stake`: 1,000,000 microSTX (1 STX)
- `query-fee`: 10,000 microSTX (0.01 STX)
- `cooldown-period`: 144 blocks (~24 hours)

## Error Codes

- `u100`: Owner only operation
- `u101`: Not a validator
- `u102`: Insufficient stake
- `u103`: Entity not found
- `u104`: Already voted on this entity
- `u105`: Invalid score (must be 0-100)
- `u106`: Insufficient balance
- `u107`: Cooldown period active
- `u108`: Validator already registered

## Weight Calculation

Validator weight is calculated as:
```
base_weight = stake / min_stake
accuracy_rate = (accurate_assessments / total_assessments) * 100
final_weight = (base_weight * accuracy_rate) / 100
```

Initial validators start with 50% assumed accuracy rate.

## Security Features

- Stake locking prevents validator misconduct
- Cooldown prevents query spam
- One assessment per validator per entity
- Historical accuracy tracking for validator credibility

## Testing

```bash
clarinet test
```

## Deployment

```bash
clarinet deploy
```

## Use Cases

- Credit scoring systems
- Product/service ratings
- Identity verification scores
- Supply chain reliability tracking
- DeFi protocol trust scores
- Community member reputation

## Future Enhancements

- Slashing mechanism for inaccurate validators
- Validator reputation decay over time
- Multi-signature requirements for high-stake assessments
- Category-specific reputation tracking
- Dispute resolution mechanism

## License

MIT
