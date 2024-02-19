# DAVINICI Token Presale

Welcome to the DAVINICI Token Presale! This repository houses the smart contracts and documentation for the presale of DAVINICI Tokens, covering both the private sale and public sale.

## Contract Information

- **Private Sale Smart Contract ID:** 0.0.4721631
- **Hashscan Link:** [DAVINCI TOKEN Private Sale](https://hashscan.io/mainnet/contract/0.0.4721631)

## Investor Onboarding and Allocation

- **Predefined Schedule:** The contract follows a set schedule that governs the participation and actions of parties involved. Investors can reserve DAVINCI tokens within the reservation window, defined by a start and end time.
- **Investor Allocation:** Only the contract owner can authorize new investors to participate in the private sale.
- **Buy Allowance Increment:** The contract owner can increase an investor's buy allowance, reflecting their commitment through additional NFTs.

## Token Reservation and Payments

- **Reservation Process:** Investors are permitted to reserve DAVINCI tokens up to their buy allowance during the designated reservation period. They must choose a stablecoin (USDC, USDC[hts], USDT[hts]) for payment and nominate a token address to influence future pairings, with 30% of their investment earmarked for liquidity pools.
- **Minimum Reservation:** The minimum reservation amount is set at 2300 DAVINCI tokens, equivalent to the allowance of a bronze-tier NFT.

## Off-Chain Calculations and NFT Commitment

- **NFT Snapshot:** Upon committing NFTs, a secure off-chain snapshot of the investor's utility NFTs from DaVinciGraph is taken to adjust their buy allowance accordingly.
- **Committed NFTs:** NFTs used for commitment are excluded from future private sale participation.

## Withdrawals

- **Investor Withdrawals:** Post-reservation, investors can withdraw their allocated DAVINCI tokens at the specified withdrawal time.
- **Owner Withdrawals:** After the private sale concludes, the owner can retrieve any unreserved DAVINCI tokens and the accumulated funds for liquidity provision on SaucerSwap.

## Payment and Pair Token Management

- **Payment Token Adjustments:** The contract owner can add or remove payment tokens, ensuring corrections for any errors unless transactions have already been executed with the said token.
- **Future Pair Token Adjustments:** The owner has the authority to manage future pair tokens, including addition and removal, provided no investor votes are tied to the token being removed.

## Contract Schedule and Amendments

- **Schedule Adjustments:** The owner can modify the start, end, and withdrawal timings within certain constraints, ensuring no postponement exceeds four months post-contract deployment and no short-term changes occur within a day's notice to prevent accidental alterations.

## Happy PreSale! 🚀✨
