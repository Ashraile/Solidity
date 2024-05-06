/// SPDX-License-Identifier: MIT
/// @author Ashraile
pragma solidity >=0.8.21 <0.9.0;

import "hardhat/console.sol";

/**
 * @dev Prototyping QOL. The GAS opcode itself costs 2 gas
 */
abstract contract Prototype {
    modifier gas() {
        uint _gas = gasleft();
         _; 
        console.log(_gas - gasleft());
    }
    bool internal immutable REMIX = (block.chainid == 1 && block.number < 1e6);
}

