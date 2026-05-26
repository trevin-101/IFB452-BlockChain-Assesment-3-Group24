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
