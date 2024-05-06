# Solidity
Solidity Projects
.

## Reflected.sol: ## 

Contract module allowing a token to incorporate reflections into its transactions. 
Inherits BEP21.sol


## VirtualStorage.sol: ##

Contract module allowing essentially infinite numbers of NFTs to be minted at a fixed gas cost by creating a virtual dynamic array of NFTs, using a bidirectional mapping with virtual incrementing default values. Supports burning (and minting with some tweaks).
Used so that {ERC721Enumerable} can work with Fractionalized NFTs.

## Console.sol ##

Hardhat module allowing for Javascript-Esque console.log functionality in Remix IDE and others.

## Prototype.sol ##

Contract for use in development environments. Includes quality-of-life functions like `console.log`, gas cost modifier `gas`, etc.
