/** SPDX-License-Identifier: MIT 
    @title ERC165 To-spec Implementation
    @custom:improv Ashraile
*/
pragma solidity ^0.8.21;

/// @notice IID: 0x01ffc9a7
interface IERC165 {
    error ERC165InvalidInterface();
    function supportsInterface(bytes4 IID) external view returns (bool); /// @dev Returns true if the contract supports the given interface.
}

/**
 * @dev Implementation of the {IERC165} interface. Contracts may inherit from this and call {_registerInterface} to declare their support of an interface.
 * Derived contracts need only register support for their own interfaces; we register support for ERC165 itself here.
 */
abstract contract ERC165 is IERC165 {

    constructor() { 
        _registerInterface(0x01ffc9a7); // bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
    }

    /// @dev See {IERC165-supportsInterface}. Time complexity O(1), guaranteed to always use less than 30 000 gas.
    mapping(bytes4 IID => bool) public supportsInterface;
    
    /// @dev Registers the contract as an implementer of an interface. `interfaceId` cannot be the ERC165 invalid interface (`0xffffffff`).
    function _registerInterface(bytes4 IID) internal virtual {
        if (IID == 0xffffffff) { revert ERC165InvalidInterface(); }
        supportsInterface[IID] = true;
    }
}

