/** SPDX-License-Identifier: MIT 
    @title ERC165.sol (To-spec implementation)
    @custom:improv Ashraile 
    @custom:version 3.0
*/
pragma solidity ^0.8.21;

/// @dev Returns true if the contract supports the given interface. @notice IID: 0x01ffc9a7
interface IERC165 {
    function supportsInterface(bytes4 IID) external view returns (bool);
}

/**
 * @dev Implementation of the {IERC165} interface. Contracts may inherit from this and call {_registerInterface} to declare their support of an interface.
 * Derived contracts need only register support for their own interfaces; we register support for ERC165 itself here.
 */
abstract contract ERC165 is IERC165 {
    constructor() { _registerInterface(0x01ffc9a7); } // => bytes4(keccak256('supportsInterface(bytes4)'))

    /// @dev See {IERC165-supportsInterface}. Time complexity O(1), guaranteed to always use less than 30 000 gas.
    mapping (bytes4 IID => bool) public supportsInterface;
    
    /// @dev Registers the contract as an implementer of an interface. `interfaceId` cannot be the ERC165 invalid interface `0xffffffff`.
    function _registerInterface(bytes4 IID) internal virtual { 
        supportsInterface[IID] = (IID != 0xffffffff);
    }
}

contract TestInterface is ERC165 {}

// ~
