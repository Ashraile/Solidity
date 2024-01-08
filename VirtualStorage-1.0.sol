
/// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.21;

address payable constant NULL = payable(0);
address payable constant BURN = payable(address(57005));

uint256 constant TRUE = 2;
uint256 constant UNTRUE = 1;
uint256 constant FALSE = 0;

error ERC721OutOfBounds(uint index);
error ERC721NonexistentToken(uint tokenID);

/// @dev A library to implement {ERC721Enumerable} with near-arbitrary numbers of contiguous NFTs (supports burning) in solidity 0.8+
/// @author Jasper Wolf (ashraile)
/// @custom:version 1.0
library VirtualStorage {

    error ERC721Empty();
    error ERC721Phantom404(uint tokenID);
    error ERC721PhantomDuplicateToken(uint tokenID);

    /// @dev Offset from zero that all token IDs start from. Default is 1. Cannot be zero.
    uint internal constant offset = 1;

    /// @dev Max nfts returned in a balance query.
    uint internal constant maxPrefetch = 50;

    /// @notice A phantom array of all the NFTs stored by the contract.
    struct TokenVault {
        mapping (uint tokenID => uint index) tokenToIndex; 
        mapping (uint index => uint tokenID) indexToToken;
        mapping (uint tokenID => uint BooleanUINT) isBought;
        uint length;
        uint releaseSupply; // uint offset;
    }

    function create(TokenVault storage Phantom, uint releaseSupply) internal {
        Phantom.length = Phantom.releaseSupply = releaseSupply;
    }

    function at(TokenVault storage Phantom, uint index) internal view returns (uint tokenID) {
        if (index >= Phantom.length) { revert ERC721OutOfBounds(index); }
        index += offset;
        tokenID = Phantom.indexToToken[index]; // defaults to zero
        return (tokenID != 0) ? tokenID : index;
    }

    // Will not revert on invalid tokenID queries
    function contains(TokenVault storage Phantom, uint tokenID) internal view returns (bool) {
        /* if ((tokenID < offset) || tokenID >= (offset + Phantom.releaseSupply)) {
            revert ERC721NonexistentToken(tokenID);
        } */
        return Phantom.isBought[tokenID] == FALSE;
    }

    // Returns up to 50 TokenIDs owned by `account`. For accounts with more than 100 NFTs, retrieve the events and store them off-chain.
    function retrieveAll(TokenVault storage Phantom) internal view returns (uint[] memory nfts, uint numberOfNFTS, string memory ErrorMessage) {  unchecked  {
        numberOfNFTS = Phantom.length;
        if (numberOfNFTS <= maxPrefetch) {
            nfts = new uint[](numberOfNFTS);
            for (uint i; i < numberOfNFTS; ++i) {
                nfts[i] = VirtualStorage.at(Phantom,i);
            }
            return (nfts, numberOfNFTS, "");
        } else {
            return (new uint[](0), numberOfNFTS, "Web3 indexing required.");
        }
        // return array from storage vs memory uint[] storage nfts
    }}
    // retrieve(50) fetchFromStartingIndex(50)

    // If you're carelessly using values at or near ~uint(0), then you deserve what happens.
    function removeFromVirtualStorage(TokenVault storage Phantom, uint tokenID) internal {  unchecked  {
        if (Phantom.length == 0) {
            revert ERC721Empty();
        }
        if (!wasCreated(Phantom, tokenID)) {
            revert ERC721NonexistentToken(tokenID); 
        }
        if (!contains(Phantom, tokenID)) {
            revert ERC721Phantom404(tokenID);
        }

        // Get the last valid index of of the mapping(s).      
        // 1. What's the stored index of this tokenID? // 2. What's the current tokenID stored at the last virtual index? 
        uint lastIndex = offset + (Phantom.length - 1);
        uint currentIndex = Phantom.tokenToIndex[tokenID];
        uint tokenIDAtLastIndex = Phantom.indexToToken[lastIndex];

        // If currentIndex (tokenToIndex) is 0, it is the default value, where currentIndex IS the token ID.
        if (currentIndex == 0) {
            Phantom.tokenToIndex[tokenID] = currentIndex = tokenID; 
        }

        // If tokenID at last index is 0, tokenIDAtLastIndex is unset, and therefore must match lastIndex
        if (tokenIDAtLastIndex == 0) {
            Phantom.indexToToken[lastIndex] = tokenIDAtLastIndex = lastIndex; 
        }

        // Swap locations in virtual array
        (Phantom.tokenToIndex[tokenIDAtLastIndex], Phantom.indexToToken[currentIndex]) = (currentIndex, tokenIDAtLastIndex);
        (Phantom.tokenToIndex[tokenID], Phantom.indexToToken[lastIndex]) = (lastIndex, tokenID);
        
        Phantom.isBought[tokenID] = TRUE;

        --Phantom.length;
    }}

    function wasCreated(TokenVault storage Phantom, uint tokenID) internal view returns (bool) {  unchecked  {
        return ((tokenID < offset) || (tokenID >= (offset + Phantom.releaseSupply))) ? false : true;
    }}

    // In this version, we will only allow adding previously minted virtual tokens back to virtual storage. 
    function addToVirtualStorage(TokenVault storage Phantom, uint tokenID) internal {  unchecked  {
        if (!wasCreated(Phantom, tokenID)) {
            revert ERC721NonexistentToken(tokenID);
        }
        if (contains(Phantom, tokenID)) {
            revert ERC721PhantomDuplicateToken(tokenID);
        }

        ++Phantom.length;

        uint lastIndex = offset + (Phantom.length - 1);

        Phantom.indexToToken[lastIndex] = tokenID;
        Phantom.tokenToIndex[tokenID] = lastIndex;

        Phantom.isBought[tokenID] = FALSE;
    }}

    function transferFromVirtualStorage() internal {}
    function transferToVirtualStorage() internal {}
}


/// @dev Example contract using VirtualStorage.sol
contract Fractional {

    using VirtualStorage for VirtualStorage.TokenVault;

    address payable public immutable THIS;

    constructor() {
        if (VirtualStorage.offset == 0) { revert("ERC721Phantom: Invalid offset."); }
        THIS = payable(address(this));
        TokenVault.create( InitialNFTSupply ); 
        // AllTokensIndex.create( InitialNFTSupply );
    }

    /// @notice All tokens owned by address(this)
    VirtualStorage.TokenVault private TokenVault; 
    // VirtualStorage.TokenVault private AllTokensIndex;  // All existing tokens.

    mapping (uint tokenID => address owner) internal owners;
    mapping (address owner => uint[] NFTs)  internal balances;
    mapping (address owner => mapping(uint => uint)) internal keymap;
    
    uint public constant InitialNFTSupply = 10;
    uint private constant TOTAL_NFT_SUPPLY = InitialNFTSupply;
    uint internal constant offset = VirtualStorage.offset;

    function removeFromVirtualStorage(uint tokenID) public {
        TokenVault.removeFromVirtualStorage(tokenID);
    }

    function addToVirtualStorage(uint tokenID) public {
        TokenVault.addToVirtualStorage(tokenID);
    }

    function wasCreated(uint tokenID) public view returns (bool) {
        return TokenVault.wasCreated(tokenID);
    }

    function buyPixel(uint tokenID) isPixel(tokenID) public payable returns (bool success) {
        // address payable self = _msgSender();
        if (isVirtualNFT(tokenID)) {
            TokenVault.removeFromVirtualStorage(tokenID);
            // enterStorage(self, tokenID);
        } else {
            revert("Token already bought from token vault.");
        }
    }

    function isVirtual(uint tokenID) private view returns (bool) { return TokenVault.contains(tokenID); }
    function isVirtualNFT(uint tokenID) private view returns (bool) { return isVirtual(tokenID); }

    function getPhantomUINTs() public view returns (uint[] memory nfts, uint, string memory) {
        return TokenVault.retrieveAll(/*50*/); // retrieveAll(50,100)
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address account, uint index) external view returns (uint) {
        return (account == address(this)) ? TokenVault.at(index) : balances[account][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public pure returns (uint) {
        return TOTAL_NFT_SUPPLY; 
        // return AllTokensIndex.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint index) public pure returns (uint) {
        // return AllTokensIndex.at(index);
        if (index >= TOTAL_NFT_SUPPLY) { revert ERC721OutOfBounds(index); }
        return index + offset;
    }

    function wasBoughtFromTokenVault(uint tokenID) isPixel(tokenID) internal view returns (bool) {
        return !TokenVault.contains(tokenID);
    }

    modifier isPixel(uint tokenID) { 
        _checkBounds(tokenID); 
        _;
    }

    function _checkBounds(uint tokenID) private pure {
        if (tokenID < offset || tokenID >= TOTAL_NFT_SUPPLY) { revert ERC721NonexistentToken(tokenID); }
    }

    function ownerOf(uint tokenID) isPixel(tokenID) public view virtual returns (address NFT_Owner) {
        return wasBoughtFromTokenVault(tokenID) ? owners[tokenID] : address(this);
    }
  
}
