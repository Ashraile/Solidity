# Solidity
Solidity Projects
.

## Reflectable.sol: ## 

Contract module allowing a token to incorporate reflections into its transactions. 
Inherits `BEP20.sol`

## Reflectable128x128.sol ##

Same as `Reflectable.sol`, but uses packed `uint128` numbers instead of `uint256`, reducing transfer gas costs by 30%.

## VirtualStorage.sol: ##

Contract module allowing essentially infinite numbers of NFTs to be minted at a fixed gas cost by creating a virtual dynamic array of NFTs, using a bidirectional mapping with virtual incrementing default values. Supports burning (and minting with some tweaks).
Used so that {ERC721Enumerable} can work with Fractionalized NFTs.

## Console.sol ##

Hardhat module allowing for Javascript-Esque console.log functionality in Remix IDE and others.

## Prototype.sol ##

Contract for use in development environments. Includes quality-of-life functions like `console.log`, gas cost modifier `gas`, etc.
