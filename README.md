# Farmescrow - Farm Input Escrow System 🗂️

## Overview

Farmescrow is a decentralized escrow platform built on Stacks blockchain that facilitates secure transactions between farm input suppliers (seeds, fertilizers, pesticides) and farmers. The system ensures that payments are only released upon verified proof of delivery, protecting both buyers and sellers in agricultural supply chains.

## Features

### 🌱 Secure Escrow Management
- Automated escrow creation and management for farm input transactions
- Multi-party verification system for delivery confirmation
- Time-locked releases with dispute resolution mechanisms
- Transparent transaction history and audit trails

### 🚛 Delivery Verification
- Proof of delivery validation through multiple verification methods
- GPS-based location confirmation for delivery addresses
- Digital signature requirements from receiving parties
- Photographic evidence submission capabilities

### 💰 Payment Protection
- Secure fund holding until delivery conditions are met
- Automatic release upon successful verification
- Refund mechanisms for failed or disputed deliveries
- Fee structure for platform sustainability

### 🔒 Security & Transparency
- Smart contract-based execution ensuring trustless operations
- Immutable transaction records on the blockchain
- Multi-signature requirements for high-value transactions
- Role-based access control for different user types

## System Architecture

The Farmescrow system consists of two main smart contracts:

1. **Escrow Manager Contract** (`escrow-manager.clar`)
   - Handles escrow creation, funding, and completion
   - Manages user registration and verification
   - Controls payment releases and refunds

2. **Delivery Tracker Contract** (`delivery-tracker.clar`)
   - Tracks delivery status and verification
   - Handles proof submission and validation
   - Manages delivery timelines and deadlines

## Key Benefits

### For Farmers
- **Payment Security**: Funds are held securely until delivery is confirmed
- **Quality Assurance**: Only verified suppliers can participate
- **Transparent Pricing**: Clear fee structure and payment terms
- **Dispute Resolution**: Built-in mechanisms for handling conflicts

### For Suppliers
- **Guaranteed Payment**: Assured payment upon successful delivery
- **Reduced Risk**: Protection against fraudulent buyers
- **Streamlined Process**: Automated workflows reduce administrative overhead
- **Market Access**: Platform provides access to a broader farmer network

### For the Agricultural Ecosystem
- **Trust Building**: Reduces information asymmetry in rural markets
- **Efficiency**: Faster, more reliable supply chain operations
- **Transparency**: All transactions are recorded and verifiable
- **Financial Inclusion**: Enables smaller suppliers to participate

## Transaction Lifecycle

1. **Escrow Creation**: Farmer creates escrow with order details and payment
2. **Supplier Acceptance**: Verified supplier accepts the order
3. **Input Preparation**: Supplier prepares and dispatches farm inputs
4. **Delivery Tracking**: Real-time tracking of delivery progress
5. **Proof Submission**: Delivery evidence submitted by supplier
6. **Verification**: Multi-party verification of delivery completion
7. **Payment Release**: Automatic payment release to supplier
8. **Transaction Complete**: Escrow closes with full audit trail

## Technical Specifications

- **Blockchain**: Stacks (Bitcoin Layer 2)
- **Smart Contract Language**: Clarity
- **Minimum Escrow Amount**: 10 STX
- **Maximum Escrow Duration**: 90 days
- **Verification Window**: 7 days after delivery claim

## Supported Farm Inputs

### Seeds & Seedlings
- Crop seeds (cereals, legumes, vegetables)
- Tree seedlings and saplings
- Flower seeds and bulbs
- Hybrid and GMO varieties

### Fertilizers & Nutrients
- Organic and synthetic fertilizers
- Micronutrient supplements
- Soil conditioners and amendments
- Liquid and granular formulations

### Pesticides & Protection
- Insecticides and herbicides
- Fungicides and bactericides
- Biological pest control agents
- Integrated pest management solutions

### Equipment & Tools
- Hand tools and implements
- Irrigation equipment
- Storage and handling equipment
- Protective gear and clothing

## Getting Started

### Prerequisites
- Clarinet development environment
- Stacks wallet for transactions
- Node.js for testing framework

### Installation
```bash
git clone [repository-url]
cd farmescrow
npm install
```

### Running Tests
```bash
clarinet test
npm test
```

### Deployment
```bash
clarinet check
clarinet deploy
```

## User Roles

### Farmers (Buyers)
- Create escrow transactions for input purchases
- Verify delivery and confirm receipt
- Submit feedback and ratings
- Access purchase history and records

### Suppliers (Sellers)
- Accept escrow orders and fulfill deliveries
- Submit proof of delivery documentation
- Manage inventory and availability
- Track payment and transaction history

### Verifiers (Third Party)
- Validate delivery proofs and evidence
- Provide independent verification services
- Resolve disputes when necessary
- Maintain verification credentials

## Security Features

- **Multi-signature Requirements**: High-value transactions require multiple approvals
- **Time-locked Escrows**: Automatic refunds if delivery deadlines are missed
- **Identity Verification**: KYC/AML compliance for registered users
- **Fraud Detection**: Automated monitoring for suspicious activities

## Compliance & Regulation

The Farmescrow system is designed with agricultural regulations in mind:
- Seed and fertilizer quality standards
- Pesticide registration and usage guidelines
- Organic certification requirements
- Cross-border trade regulations

## Future Enhancements

- IoT integration for automated delivery confirmation
- AI-powered quality assessment from delivery photos
- Integration with agricultural insurance platforms
- Mobile app for farmers and suppliers
- Multi-language support for global adoption

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.

## Support

For technical support or questions about the Farmescrow system:
- Create an issue in this repository
- Contact the development team
- Join our community Discord server

---

*Farmescrow: Securing agricultural supply chains through blockchain technology*
