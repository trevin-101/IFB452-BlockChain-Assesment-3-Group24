# IFB452-BlockChain-Assesment-3-Group 24
IFB452 BlockChain Assesment 3 by Group 24
Queensland University of Technology

A blockchain-based supply chain solution for tracking fuel distribution in Australia, designed to provide transparency and prevent hoarding during national fuel shortages.

---

## Project Overview

FuelGuard records fuel batches from import terminals through wholesalers and retailers to consumers. Every transfer of custody is recorded on the Ethereum blockchain, creating an immutable audit trail that regulators (ACCC) and the public can verify.

### Key features
- Role-based access control: Admin, Importer, Wholesaler, Retailer, Regulator
- Parent/child batch tracking: supports partial volume transfers with full provenance
- Multi-contract architecture: separation of concerns across three smart contracts
- Public auditability: anyone can query batch history and stakeholder holdings
- MetaMask integration: interact through a browser-based dApp

### Stakeholders

Admin: Deploys contracts and grants roles 
Importer: Records new fuel batches arriving at port, allocate them to wholesalers
Wholesaler: Receives fuel from importer and distributes to retailers 
Retailer: Receives fuel from wholesaler and confirms delivery 
Regulator (ACCC): Read-only audit access 


---

## Architecture
FuelGuardRecord (state):          
- Stores all batch data and roles               
- Auto-grants ADMIN_ROLE to deployer            
- Only the Allocation contract can write to     
  batch state (via onlyAllocationContract)
  
FuelGuardAllocation (cross-contract calls to FuelGuardRecord):
- allocateToWholesaler      
- distributeToRetailer    
- confirmDelivery
   
 FuelGuardVerification (read-only calls to FuelGuardRecord):
 - getBatchDetails
 - getBatchHistory
 - getCurrentHoldings

### Lifecycle states


Recorded -> AllocatedToWholesaler -> InTransitToRetailer -> Delivered


---

## Tech Stack

| Layer | Technology |
|---|---|
| Smart contracts | Solidity 0.8.20+ |
| Development | Remix IDE |
| Network | Ethereum Sepolia testnet |
| Frontend | HTML + JavaScript + Web3.js 1.10.0 |
| Wallet | MetaMask |
| BPMN modelling | SAP Signavio |

---
## Repository Structure

Backend/

    └── FuelGuard.sol
    
Frontend/

    └── index.html

docs/

  └── Group 24.pdf
  
  └── BPMN-Collaboration Diagram.pdf

README.md

---
## Prerequiresites

Before running the project you need:

1. MetaMask: browser extension — [install here](https://metamask.io)
2. Sepolia testnet ETH: get free test ETH from a faucet:
   - [Google Sepolia Faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia)
   - [Alchemy Sepolia Faucet](https://sepoliafaucet.com)
3. A local HTTP server: to run the frontend (one of):
   - VS Code + Live Server extension
   - Python 3 (`python -m http.server`)
   - Node.js + http-server (`npx http-server`)
4. At least 5 MetaMask accounts representing different stakeholders:
   - Admin (deployer)
   - Importer
   - Wholesaler
   - Retailer
   - Regulator

---
## How to run 

This project has two part to set up: the smart contract (one-time deployment) and frontend dApp.

### Part 1: Deploy smart contracts

1. Open [Remix IDE](https://remix.ethereum.org) in your browser.
2. In File Explorer, create a new file `FuelGuard.sol` and paste the contents of `contracts/FuelGuard.sol`.
3. Go to the **Solidity Compiler** tab and compile with version `0.8.20` or higher.
4. Switch to the **Deploy & Run** tab.
5. Set **ENVIRONMENT** to `Browser Extension` select `Sepolia Testnet-Metamask`
6. Confirm MetaMask is on the **Sepolia** network and using your **Admin** account.
7. Deploy the three contracts **in this order**:
   
   ```
   1. FuelGuardRecord       (no constructor args)
   2. FuelGuardAllocation   (constructor arg: Record address)
   3. FuelGuardVerification (constructor arg: Record address)
   ```
8. After deployment, copy each contract's address from the Deployed Contracts panel.

### Part 2 — Link the contracts

After deploying, the Record contract needs to know the Allocation contract's address before it will accept any allocation calls.

1. Make sure MetaMask is on the **Admin** account.
2. In Remix, expand `FuelGuardRecord` in Deployed Contracts.
3. Find the `setAllocationContract` function.
4. Paste the **Allocation contract's address** as the argument.
5. Click `transact` and confirm in MetaMask.

> NOTE: **Without this step, allocateToWholesaler and distributeToRetailer will always fail.**

### Part 3 — Grant roles

Still as Admin, grant a role to each stakeholder account.

For each role:
1. Click the role's identifier button (`IMPORTER_ROLE`, `WHOLESALER_ROLE`, etc.) to copy its bytes32 value.
2. Call `grantRole(account, role)`:
   - `account`: the stakeholder's wallet address
   - `role`: the bytes32 value
3. Confirm in MetaMask.

Repeat for all four stakeholder roles (Importer, Wholesaler, Retailer, Regulator).

### Part 4 — Configure the frontend

1. Open `Frontend/index.html` in a text editor.
2. Find these placeholders near the top of the `<script>` section:

   ```javascript
   const recordAddress       = '';
   const allocationAddress   = '';
   const verificationAddress = '';

   const recordABI       = [];
   const allocationABI   = [];
   const verificationABI = [];
   ```

3. Paste your three contract addresses.
4. Copy each contract's ABI from Remix:
   - Solidity Compiler tab → select the contract from dropdown → click the ABI copy icon
   - Paste each ABI into the corresponding variable (replace the `[]`)
5. Save the file.
