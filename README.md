# Carbon Credit NFT Smart Contract - README

## Overview

This smart contract, written in **Clarity**, implements a **Carbon Credit NFT Marketplace**. It facilitates the creation, management, and secure tracking of carbon credit tokens in the form of **Non-Fungible Tokens (NFTs)**. The contract is designed for use in carbon offset programs, enabling reliable tokenization of environmental credits.

---

## Key Features

### 1. Minting
- **Single Credit Minting:** Create individual carbon credits with unique token IDs.
- **Batch Minting:** Mint multiple credits simultaneously with a maximum limit of 50 per batch.

### 2. Metadata
- Associate each token with a URI for external resource linkage.
- Manage metadata for token batches.

### 3. Ownership
- Securely track ownership to ensure proper credit transfers.
- Only the contract owner can mint new credits.

### 4. Burning
- Retire credits to prevent reuse.
- Burned credits are immutable and cannot be transferred.

### 5. Validation
- Ensures URI format validity for metadata integrity.
- Enforces batch size limits to maintain system constraints.

---

## Security Highlights
- **Restricted Minting:** Only the contract owner can issue new credits.
- **Burn Integrity:** Prevent actions on burned credits, ensuring data reliability.
- **Ownership Validation:** Validates token ownership for secure transactions.

---

## Intended Use
This contract is designed for:
- Carbon offset marketplaces.
- Tokenization of environmental credits for secure trading.
- Transparent and reliable tracking of carbon credit lifecycles.

---

## Contract Structure

### Constants
- `contract-owner`: Represents the deployer of the contract.
- `max-batch-size`: Limits the number of credits minted in a batch to 50.
- Various error codes for minting, burning, and validation failures.

### Data Variables
- `last-credit-id`: Tracks the ID of the last minted token.

### Maps
- `credit-uri`: Maps token IDs to their associated URIs.
- `burned-credits`: Tracks which credits have been burned.
- `batch-metadata`: Stores metadata for credit batches.

---

## Available Functions

### Public Functions
1. **Mint a Single Credit**  
   `mint-carbon-credit(credit-uri-data)`  
   Mint a single carbon credit with the provided metadata URI.

2. **Batch Mint Credits**  
   `batch-mint-carbon-credits(uris)`  
   Mint multiple credits in one transaction. Validates the batch size and URI formats.

3. **Burn a Credit**  
   `burn-carbon-credit(credit-id)`  
   Retire a carbon credit by its ID. Only the token owner can burn the credit.

4. **Transfer a Credit**  
   `transfer-carbon-credit(credit-id, sender, recipient)`  
   Transfer ownership of a carbon credit securely.

5. **Update Metadata**  
   `update-credit-uri(credit-id, new-uri)`  
   Update the URI for an existing carbon credit.

---

### Read-Only Functions
1. **Get Credit Metadata**  
   `get-credit-uri(credit-id)`  
   Fetch the URI linked to a specific credit ID.

2. **Get Credit Owner**  
   `get-credit-owner(credit-id)`  
   Retrieve the owner of a given credit.

3. **Check Burn Status**  
   `is-credit-burned-status(credit-id)`  
   Verify whether a specific credit has been burned.

4. **Get Last Minted Credit ID**  
   `get-last-credit-id()`  
   Retrieve the ID of the last minted credit.

5. **Fetch Batch Metadata**  
   `get-batch-credit-ids(start-id, count)`  
   Fetch metadata for a range of credits starting from a specific ID.

---

## Security Notes
- **Owner-only Minting:** The `tx-sender` must match the `contract-owner` for minting operations.
- **Burn Protection:** Burned credits cannot be reused or transferred.
- **Validation:** URI and batch size are validated to prevent malformed data.

---

## Initialization
Upon deployment, the contract initializes the `last-credit-id` to `0` to start the token ID sequence.

---

## Usage Instructions

1. **Deploy the Contract:** Ensure you are the deployer to assume the `contract-owner` role.
2. **Mint Credits:** Use `mint-carbon-credit` or `batch-mint-carbon-credits` to create new tokens.
3. **Burn Credits:** Use `burn-carbon-credit` to retire a credit after use.
4. **Transfer Ownership:** Use `transfer-carbon-credit` for secure credit transactions.
5. **Track Metadata:** Query the metadata using read-only functions.

---

## Example Interactions

### Mint a Single Credit
```clarity
(define-public (mint-carbon-credit (credit-uri-data "https://example.com/credit1")))
```

### Burn a Credit
```clarity
(define-public (burn-carbon-credit u1))
```

### Transfer a Credit
```clarity
(define-public (transfer-carbon-credit u1 tx-sender recipient))
```

---

## Contributing
Contributions to enhance the contract or documentation are welcome. Please submit issues or pull requests with detailed descriptions.

---

## License
This project is licensed under the MIT License.
```