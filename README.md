# 🎭 Fanmint - Fan Token Engine for Creators

> 🚀 Reward your supporters with exclusive perks using blockchain-powered fan tokens!

## 📖 Overview

Fanmint is a Clarity smart contract that enables creators to build engaged communities by issuing fan tokens to supporters and offering exclusive perks that can be claimed using these tokens. It's like Patreon meets cryptocurrency! 

## ✨ Features

- 🎨 **Creator Registration**: Artists, musicians, and content creators can register their profiles
- 💰 **Fan Token System**: Supporters earn tokens when they financially support creators
- 🎁 **Exclusive Perks**: Creators can offer limited edition perks claimable with fan tokens
- 📊 **Support Tracking**: Complete history of supporter relationships
- 💎 **Token Economy**: Dual token distribution (both creator and supporter receive tokens)
- 🛡️ **Platform Fees**: Built-in fee mechanism for platform sustainability

## 🔧 Core Functions

### For Creators 👨‍🎨

#### Register as Creator
```clarity
(contract-call? .fanmint register-creator "Artist Name" "Description of your work")
```

#### Create Exclusive Perks
```clarity
(contract-call? .fanmint create-perk "VIP Discord Access" "Join exclusive creator Discord" u100 u50)
```

#### Toggle Status
```clarity
(contract-call? .fanmint toggle-creator-status)
(contract-call? .fanmint toggle-perk-status u1)
```

### For Supporters 🙋‍♀️

#### Support a Creator
```clarity
(contract-call? .fanmint support-creator 'SP1234...CREATOR u1000000)
```

#### Claim Perks
```clarity
(contract-call? .fanmint claim-perk u1)
```

### Read-Only Functions 📖

#### Check Balances & Info
```clarity
(contract-call? .fanmint get-fan-token-balance 'SP1234...USER)
(contract-call? .fanmint get-creator-info 'SP1234...CREATOR)
(contract-call? .fanmint get-perk-info u1)
(contract-call? .fanmint has-claimed-perk 'SP1234...USER u1)
```

## 🎯 How It Works

1. **🎪 Creator Setup**: Creators register with name and description
2. **💝 Fan Support**: Supporters send STX to support creators
3. **🪙 Token Distribution**: Both creator and supporter receive fan tokens (minus platform fee)
4. **🎁 Perk Creation**: Creators design exclusive perks with token costs and supply limits
5. **🎊 Perk Claiming**: Supporters burn fan tokens to claim exclusive perks
6. **📈 Community Growth**: Repeat cycle builds engaged token-based communities

## 💡 Use Cases

- 🎵 **Musicians**: Offer backstage passes, exclusive tracks, concert tickets
- 🎨 **Artists**: Limited edition prints, commission slots, art tutorials  
- 📹 **Content Creators**: Private Discord access, early video access, merchandise
- 📚 **Writers**: Exclusive chapters, signed books, writing workshops
- 🎮 **Gamers**: Custom game sessions, exclusive content, beta access

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Deployment
```bash
clarinet deploy --testnet
```

### Testing
```bash
clarinet test
```

## 🔒 Security Features

- ✅ Owner-only administrative functions
- ✅ Input validation on all parameters  
- ✅ Balance checks before token operations
- ✅ Authorization checks for perk management
- ✅ Supply limit enforcement for perks

## 📊 Token Economics

- **Support Flow**: STX → Platform Fee + Creator Tokens + Supporter Tokens
- **Default Platform Fee**: 2.5% (250 basis points)
- **Token Distribution**: 1:1 ratio between creator and supporter
- **Perk Economy**: Burn tokens to claim exclusive perks

## 🛠️ Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Resource not found |
| u102 | Insufficient balance |
| u103 | Resource already exists |
| u104 | Invalid amount |
| u105 | Unauthorized access |
| u106 | Perk not available |
| u107 | Insufficient tokens |

## 🤝 Contributing

Feel free to submit issues and enhancement requests! This is an MVP implementation with room for additional features like:

- 🔄 Token staking mechanisms
- 🏆 Tiered supporter levels  
- 📅 Time-limited perks
- 🔗 Cross-creator collaborations
- 📱 Mobile app integration


