# Manual Tenderly Contract Setup

## Why Manual Setup?

The Tenderly API currently has issues adding Celo network contracts programmatically. You'll need to add the multisig contracts manually through the Tenderly UI.

## Steps to Add Contracts

1. **Go to your Tenderly project:**
   https://dashboard.tenderly.co/philipThe2nd/project/contracts

2. **Click "Add Contract"**

3. **Add the Mento Labs Multisig:**

   - Network: **Celo** (or Celo Mainnet)
   - Address: `0x655133d8E90F8190ed5c1F0f3710F602800C0150`
   - Name: `Mento Labs Multisig`

4. **Add the Reserve Multisig:**
   - Network: **Celo** (or Celo Mainnet)
   - Address: `0x87647780180B8f55980C7D3fFeFe08a9B29e9aE1`
   - Name: `Reserve Multisig`

## Verification

After adding the contracts, you should see them listed in:

- The Tenderly UI under Contracts
- Any transactions from these addresses should now be tracked

## Note

Once the contracts are added manually, the Terraform alerts will work correctly. The alerts reference the contract addresses directly, so they don't depend on the contracts being added via Terraform.
