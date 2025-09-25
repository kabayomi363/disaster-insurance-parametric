# Disaster Insurance Parametric System

A blockchain-based parametric disaster insurance system using weather data and satellite imagery for automatic claim payouts based on predetermined triggers and conditions.

## Overview

This smart contract system provides parametric disaster insurance that automatically triggers payouts based on objective weather data and satellite imagery. The system eliminates traditional claims processing by using predefined parameters to determine coverage and execute instant payouts.

## Features

### Core Functionality
- **Parametric Coverage**: Insurance based on measurable parameters (rainfall, wind speed, temperature)
- **Automatic Payouts**: Instant claim settlement based on weather triggers
- **Weather Data Integration**: Real-time weather data processing for trigger evaluation
- **Satellite Imagery**: Satellite data integration for damage assessment
- **Multi-Disaster Support**: Coverage for various natural disasters (floods, droughts, hurricanes)

### Smart Contracts
- `parametric-insurance`: Main contract processing weather data triggers and executing automatic payouts

## System Architecture

The system consists of smart contracts built on the Stacks blockchain using Clarity language:

### Parametric Insurance Contract
Handles the core insurance functionality including:
- Policy creation and premium calculation
- Weather data trigger evaluation
- Automatic payout execution
- Multi-parameter coverage management
- Risk assessment and pricing

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing
- Node.js environment

### Installation
1. Clone the repository
2. Install dependencies: `npm install`
3. Run tests: `clarinet test`
4. Deploy contracts: `clarinet deploy`

## Usage

### Policy Creation
Create parametric insurance policies with specific weather trigger conditions and coverage amounts.

### Weather Data Processing
Process real-time weather data to evaluate trigger conditions and determine payout eligibility.

### Automatic Claims
Automated claim processing and payout execution based on predefined parameters.

## Development

This project uses Clarinet for smart contract development and testing.

### Commands
- `clarinet check` - Validate contract syntax
- `clarinet test` - Run test suite
- `clarinet deploy` - Deploy to network

## Contributing

Please read our contributing guidelines before submitting pull requests.

## License

This project is licensed under the MIT License.