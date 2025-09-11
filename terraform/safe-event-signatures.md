# Safe Contract Event Signatures Reference

This document contains the keccak256 hashes for Safe v1.3.0 contract events used in Tenderly alerts.

## Event Signatures Table

| Event Name                     | Event Signature                                                                                            | Keccak256 Hash                                                       | Channel   |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | --------- |
| **SafeSetup**                  | `SafeSetup(address,address[],uint256,address,address)`                                                     | `0x141df868a6331af528e38c83b7aa03edc19be66e37ae67f9285bf4f8e3c6a1a8` | 🚨 Alerts |
| **AddedOwner**                 | `AddedOwner(address)`                                                                                      | `0x9465fa0c962cc76958e6373a993326400c1c94f8be2fe3a952adfa7f60b2ea26` | 🚨 Alerts |
| **RemovedOwner**               | `RemovedOwner(address)`                                                                                    | `0xf8d49fc529812e9a7c5c50e69c20f0dccc0db8fa95c98bc58cc9a4f1c1299eaf` | 🚨 Alerts |
| **ChangedThreshold**           | `ChangedThreshold(uint256)`                                                                                | `0x610f7ff2b304ae8903c3de74c60c6ab1f7d6226b3f52c5161905bb5ad4039c93` | 🚨 Alerts |
| **ChangedFallbackHandler**     | `ChangedFallbackHandler(address)`                                                                          | `0x5ac6c46c93519d78e5e78d13553cc846b05b929af8cec273a4da640ef71518b2` | 🚨 Alerts |
| **EnabledModule**              | `EnabledModule(address)`                                                                                   | `0xecdf3a3effea5783a3c4c2140e677577666428d44ed9d474a0b3a4c9943f8440` | 🚨 Alerts |
| **DisabledModule**             | `DisabledModule(address)`                                                                                  | `0xe009cfde5f0e68181a3a13f192effb5e90e7a6a35744c6302aebcf7e6ea6a41e` | 🚨 Alerts |
| **ChangedGuard**               | `ChangedGuard(address)`                                                                                    | `0x1151116914515bc0891ff9047a6cb32cf902546f83066499bcf8ba33d2353fa2` | 🚨 Alerts |
| **ExecutionSuccess**           | `ExecutionSuccess(bytes32,uint256)`                                                                        | `0x442e715f626346e8c54381002da614f62bee8d27386535b2521ec8540898556e` | 🔔 Events |
| **ExecutionFailure**           | `ExecutionFailure(bytes32,uint256)`                                                                        | `0x23428b18acfb3ea64b08dc0c1d296ea9c09702c09083ca5272e64d115b687d23` | 🔔 Events |
| **ApproveHash**                | `ApproveHash(bytes32,address)`                                                                             | `0xf2a0eb156472d1440255b0d7c1e19cc07115d1051fe605b0dce69acfec884d9c` | 🔔 Events |
| **SignMsg**                    | `SignMsg(bytes32)`                                                                                         | `0xe7f4675038f4f6034dfcbbb24c4dc08e4ebf10eb9d257d3d02c0f38d122ac6e4` | 🔔 Events |
| **SafeModuleTransaction**      | `SafeModuleTransaction(address,address,uint256,bytes,uint8)`                                               | `0xb648d3644f584ed1c2232d53c46d87e693586486ad0d1175f8656013110b714e` | 🔔 Events |
| **ExecutionFromModuleSuccess** | `ExecutionFromModuleSuccess(address)`                                                                      | `0x6bb56a14aadc7530dc9cd8ce06ef9aa3e2fb53d2e6c0a84e08a2982473a19a02` | 🔔 Events |
| **SafeReceived**               | `SafeReceived(address,uint256)`                                                                            | `0x3d0ce9bfc3ed7d6862dbb28b2dea94561fe714a1b4d019aa8af39730d1ad7c3d` | 🔔 Events |
| **SafeMultiSigTransaction**    | `SafeMultiSigTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes,bytes)` | `0x66753e819721f3c7a15c0e713f8dd6b103a123eb3a06a1ad39ab18d3b094ad85` | 🔔 Events |

## Channel Descriptions

### 🚨 Alerts Channel

Critical security events that require immediate attention:

- Configuration changes (owners, threshold, modules)
- Security-critical operations
- System setup events

### 🔔 Events Channel

Regular operational events for monitoring:

- Transaction executions
- Approval processes
- Fund movements
- Module operations

## Generating Event Signatures

To generate or verify these signatures, you can use:

### Foundry Cast (Recommended)

> **Prerequisites**: Install Foundry by running `curl -L https://foundry.paradigm.xyz | bash` and then `foundryup`

```bash
# Generate event signature hash using cast
cast sig-event "SafeSetup(address,address[],uint256,address,address)"
# Output: 0x141df868a6331af528e38c83b7aa03edc19be66e37ae67f9285bf4f8e3c6a1a8

# Or using cast keccak for the raw signature
cast keccak "SafeSetup(address,address[],uint256,address,address)"
# Output: 0x141df868a6331af528e38c83b7aa03edc19be66e37ae67f9285bf4f8e3c6a1a8

# Generate multiple signatures at once
cast sig-event "AddedOwner(address)"
# Output: 0x9465fa0c962cc76958e6373a993326400c1c94f8be2fe3a952adfa7f60b2ea26

cast sig-event "ExecutionSuccess(bytes32,uint256)"
# Output: 0x442e715f626346e8c54381002da614f62bee8d27386535b2521ec8540898556e
```

### Generate All Safe Event Signatures Script

```bash
#!/bin/bash
# generate-safe-events.sh - Generate all Safe contract event signatures

echo "# Safe Contract Event Signatures"
echo ""
echo "# Security Events (🚨 Alerts Channel)"
cast sig-event "SafeSetup(address,address[],uint256,address,address)"
cast sig-event "AddedOwner(address)"
cast sig-event "RemovedOwner(address)"
cast sig-event "ChangedThreshold(uint256)"
cast sig-event "ChangedFallbackHandler(address)"
cast sig-event "EnabledModule(address)"
cast sig-event "DisabledModule(address)"
cast sig-event "ChangedGuard(address)"
echo ""
echo "# Operational Events (🔔 Events Channel)"
cast sig-event "ExecutionSuccess(bytes32,uint256)"
cast sig-event "ExecutionFailure(bytes32,uint256)"
cast sig-event "ApproveHash(bytes32,address)"
cast sig-event "SignMsg(bytes32)"
cast sig-event "SafeModuleTransaction(address,address,uint256,bytes,uint8)"
cast sig-event "ExecutionFromModuleSuccess(address)"
cast sig-event "SafeReceived(address,uint256)"
cast sig-event "SafeMultiSigTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes,bytes)"
```

### Alternative: Using Cast with Safe Contract

```bash
# Get all events from a deployed Safe contract
cast events --rpc-url https://forno.celo.org 0x655133d8E90F8190ed5c1F0f3710F602800C0150

# Decode a specific event from transaction logs
cast logs --rpc-url https://forno.celo.org --address 0x655133d8E90F8190ed5c1F0f3710F602800C0150 "SafeSetup(address,address[],uint256,address,address)"
```

### Solidity

```solidity
bytes32 eventHash = keccak256("SafeSetup(address,address[],uint256,address,address)");
```

## Safe Contract References

### Safe Smart Contracts Repository

- [Safe Smart Contracts GitHub](https://github.com/safe-global/safe-smart-contracts) - Official repository for Safe smart contracts
- [Safe v1.3.0 Release](https://github.com/safe-global/safe-smart-contracts/releases/tag/v1.3.0) - Specific v1.3.0 release tag
- [Safe.sol v1.3.0 Source](https://github.com/safe-global/safe-smart-contracts/blob/v1.3.0/contracts/Safe.sol) - Safe v1.3.0 contract source code

### Safe Documentation

- [Safe Core Documentation](https://docs.safe.global/) - Official Safe documentation hub
- [Smart Account Signatures](https://docs.safe.global/advanced/smart-account-signatures) - Guide on Safe signature mechanisms
- [Safe SDK Protocol Kit](https://docs.safe.global/sdk/protocol-kit) - Protocol Kit documentation including events

### Safe Deployments

- [Safe Deployments Repository](https://github.com/safe-global/safe-deployments) - Official deployment addresses for all networks
- [Safe Deployments NPM Package](https://www.npmjs.com/package/@safe-global/safe-deployments) - NPM package with deployment information
- [Celo Network Deployments](https://github.com/safe-global/safe-deployments/tree/main/src/assets/v1.3.0) - v1.3.0 deployment addresses including Celo

### Additional Resources

- [Safe Forum - Contract v1.4.0](https://forum.safe.global/t/safe-contract-v1-4-0/2109) - Discussion on Safe contract evolution
- [Safe Contract Package](https://www.npmjs.com/package/@safe-global/safe-contracts) - NPM package for Safe contracts

## Network Information

### Celo Network IDs

- **Celo Mainnet**: 42220
- **Celo Testnet (Alfajores)**: 44787
- **Celo Sepolia**: TBD (upcoming replacement for Alfajores)

### Safe Deployment Addresses on Celo (v1.3.0)

Common Safe contracts deployed on Celo mainnet:

- **Safe Singleton**: Check [safe-deployments](https://github.com/safe-global/safe-deployments/tree/main/src/assets/v1.3.0) for specific addresses
- **Safe Proxy Factory**: See deployment repository for factory addresses
- **Multi Send**: Available in the safe-deployments package

## Notes

1. These signatures are for Safe v1.3.0. Different Safe versions may have different event signatures.
2. Always verify event signatures against your specific Safe contract version.
3. The `event_id` in Tenderly alerts expects the full keccak256 hash including the `0x` prefix.
4. Event parameter types must match exactly (e.g., `address[]` not `address`).
