# DigitalBazaar - Decentralized NFT Marketplace

A comprehensive decentralized marketplace built on Stacks blockchain for trading digital assets including NFTs, with built-in escrow, royalty distribution, and user rating systems.

## Features

### Core Marketplace
- **Asset Listings**: Create time-bound listings for digital assets
- **Escrow System**: Secure 24-hour escrow period for all transactions  
- **Royalty Payments**: Automatic royalty distribution to original creators
- **User Ratings**: Community-driven reputation system
- **Category Support**: Organize assets by categories for better discovery

### Security & Trust
- **Escrow Protection**: Buyer funds held in escrow until transaction completion
- **Marketplace Fees**: Transparent 2.5% platform fee structure
- **Ownership Verification**: On-chain asset ownership tracking
- **Emergency Controls**: Marketplace pause functionality for critical situations

### Financial Management
- **Balance System**: Internal balance management for seamless trading
- **Multi-party Payouts**: Automatic distribution to sellers, creators, and platform
- **Volume Tracking**: Real-time marketplace volume and statistics
- **Treasury Management**: Platform fee collection and withdrawal

## Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| `LISTING-DURATION` | 1008 blocks (~7 days) | How long listings remain active |
| `MIN-PRICE` | 1,000 tokens | Minimum asset listing price |
| `MARKETPLACE-FEE` | 250 basis points (2.5%) | Platform transaction fee |
| `MAX-ROYALTY` | 1000 basis points (10%) | Maximum creator royalty |
| `ESCROW-PERIOD` | 144 blocks (~24 hours) | Escrow hold duration |

## Quick Start

### For Sellers

1. **Register your asset** (marketplace owner function):
```clarity
(contract-call? .digitalbazaar register-asset "unique-asset-id" 'SP123...)
```

2. **Create a listing**:
```clarity
(contract-call? .digitalbazaar create-listing 
    "unique-asset-id" 
    u50000                    ;; Price in tokens
    (some 'SP456...)         ;; Royalty recipient (optional)
    u500                     ;; 5% royalty
    "digital-art")           ;; Category
```

### For Buyers

1. **Deposit funds**:
```clarity
(contract-call? .digitalbazaar deposit-funds u100000)
```

2. **Purchase asset**:
```clarity
(contract-call? .digitalbazaar purchase-asset u0)  ;; Listing ID 0
```

3. **Complete purchase** (after escrow period):
```clarity
(contract-call? .digitalbazaar complete-purchase u0)
```

4. **Rate the seller**:
```clarity
(contract-call? .digitalbazaar rate-user 'SP123... u5)  ;; 5-star rating
```

## Public Functions

### Marketplace Operations
- `create-listing(asset-id, price, royalty-recipient, royalty-percentage, category)` - List asset for sale
- `purchase-asset(listing-id)` - Buy listed asset (enters escrow)
- `complete-purchase(listing-id)` - Finalize purchase after escrow period
- `cancel-listing(listing-id)` - Cancel active listing

### Financial Functions
- `deposit-funds(amount)` - Add tokens to marketplace balance
- `withdraw-funds(amount)` - Withdraw tokens from marketplace balance
- `rate-user(user, rating)` - Rate user after transaction (1-5 stars)

### Administrative Functions
- `register-asset(asset-id, owner)` - Register new asset (owner only)
- `toggle-marketplace(active)` - Enable/disable marketplace (owner only)
- `withdraw-treasury(amount)` - Withdraw platform fees (owner only)

## Query Functions

### Listing Information
- `get-listing(listing-id)` - Get complete listing details
- `get-marketplace-stats()` - Get platform statistics

### User Information  
- `get-user-balance(user)` - Check user's marketplace balance
- `get-user-rating(user)` - Get user's average rating
- `get-asset-owner(asset-id)` - Check current asset owner
- `get-escrow-info(listing-id, buyer)` - Check escrow status

## Fee Structure

### Transaction Fees
- **Platform Fee**: 2.5% of sale price (goes to treasury)
- **Creator Royalty**: 0-10% of sale price (set per listing)
- **Seller Receives**: Sale price - Platform fee - Royalty

### Example Transaction (10,000 token sale, 5% royalty):
- Platform fee: 250 tokens (2.5%)
- Creator royalty: 500 tokens (5%)
- Seller receives: 9,250 tokens (92.5%)

## Security Features

### Escrow Protection
- All purchases go through 24-hour escrow period
- Buyers can't lose funds to malicious sellers
- Asset ownership transfers only after escrow completion

### Access Controls
- Asset registration restricted to marketplace owner
- Only asset owners can create listings
- Marketplace can be paused in emergencies

### Validation Checks
- Price minimums prevent spam listings
- Royalty caps prevent excessive fees  
- Balance verification prevents insufficient fund transactions
- Self-purchase prevention

## Development

### Prerequisites
- Stacks blockchain development environment
- Clarity language tools
- Testing framework (Clarinet recommended)

### Local Development
```bash
# Run tests
clarinet test

# Check contract
clarinet check

# Deploy locally
clarinet deploy --network devnet
```

### Contract Deployment
```bash
# Deploy to testnet
clarinet deploy --network testnet

# Deploy to mainnet
clarinet deploy --network mainnet
```

## Marketplace Statistics

The contract tracks comprehensive marketplace metrics:
- Total number of listings created
- Total trading volume in tokens
- Platform treasury balance
- Current marketplace status (active/paused)

## User Experience

### Rating System
- 5-star rating system for user reputation
- Ratings calculated as average across all transactions
- Builds trust and accountability in the marketplace

### Categories
Support for asset categorization enables:
- Better asset discovery
- Filtered browsing
- Specialized marketplaces

## Error Codes

| Code | Description |
|------|-------------|
| u300 | Not authorized for this action |
| u301 | Listing not found |
| u302 | Invalid price (too low) |
| u303 | Asset already listed |
| u304 | Listing has expired |
| u305 | Asset already sold |
| u306 | Insufficient funds |
| u307 | Invalid asset |
| u308 | Royalty percentage too high |
| u309 | Marketplace is closed |
| u310 | Cannot purchase own asset |

## Roadmap

- **Phase 1**: Core marketplace functionality ✅
- **Phase 2**: Advanced filtering and search
- **Phase 3**: Auction mechanisms
- **Phase 4**: Multi-token support
- **Phase 5**: Cross-chain asset bridging

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

**DigitalBazaar** - Empowering creators and collectors through secure, decentralized asset trading.