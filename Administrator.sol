/// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/* @dev Provides information about the current execution context, including the sender of the transaction and its data. While these are generally available
    via msg.sender and msg.data, they should not be accessed in such a direct manner, since when dealing with GSN meta-transactions the account sending and
    paying for execution may not be the actual sender (as far as an application is concerned).
    This contract is only required for intermediate, library-like contracts. 
*/
abstract contract Context {
    
    function _msgSender() internal view virtual returns (address payable) { 
        return payable( msg.sender );
    }
    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

/**
 * @dev Contract module which provides an advanced access control mechanism, where
 * there is an account (an administrator) that can be granted exclusive access to specific functions. 
   Additionally, levels of access are gatekept by an access mapping, which can be set with {downgradeAccess} and {setAccessClearance}
   Can be used to grant partial ownership of a contract to another account, without fully granting administrative control.
 *
 * By default, the administrator account will be the one that deploys the contract. This can later be changed with {reassignOwnership}.
 *
 * This module is used through inheritance. It will make available the `onlyAdmin`, and `level[x]` modifiers, which can be applied to your functions 
   to restrict their uses
*/

abstract contract Administrator is Context {

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event AccessSet(address indexed setter, address indexed account, uint indexed clearance, uint time);

    address payable public administrator;

    address payable public owner;
    address private previousOwner;

    uint private constant MAX_CLEARANCE = 5; // Can be set arbitrarily high.
    uint private constant MIN_CLEARANCE = 0; // Access level 0: no access privileges.

    // bytes32 private constant errstr = "Admin: Insufficient clearance.";

    uint8 private constant version = 1;

    uint lockTime;

    // Initialize values
    constructor() {

        administrator = payable(_msgSender());

        UAC[ _msgSender() ].access = MAX_CLEARANCE; // set UAC
        
        emit AccessSet( address(0), _msgSender(), MAX_CLEARANCE, block.timestamp);
    }

    struct UserAccountControl {
        address account;
        uint access; // default 0
        bool isLevelLocked; // default false
    }

     // Different addresses can map to different owner privileges.
    mapping (address => UserAccountControl) internal UAC;

    /// @dev Explicit owner check. Disallow potential null address key discovery.
    modifier onlyOwner { 
        require( _msgSender() == owner && _msgSender() != address(0), "Admin: You are not the owner."); 
        _;
    }

    /// @dev Explicit administrator check. Other accounts can have max clearance but are not the administrator.
    modifier onlyAdmin {
        require( _msgSender() == administrator && _msgSender() != address(0), "Admin: You are not the administrator.");
        _;
    }

    // For extending this to arbitrary levels just put a require statement within your function: require( accounts[account].access > SOME_NUMBER )
    // And create a modifier where it warrants reuse.

    // maximum clearance but not administrator / owner
    modifier max_level {
        require( UAC[_msgSender()].access == MAX_CLEARANCE, "Admin: Insufficient clearance."); _;
    }

    modifier level4 {
        require( UAC[_msgSender()].access > 3, "Admin: Insufficient access." ); _;
    }

    modifier level3 {
        require( UAC[_msgSender()].access > 2, "Admin: Insufficient access." ); _;
    }

    modifier level2 {
        require( UAC[_msgSender()].access > 1, "Admin: Insufficient privilege." ); _;
    }

    modifier level1 {
        require( UAC[_msgSender()].access > 0, "Check your privilege." ); _;
    }

    /// @dev Set a cap on who can change access clearance by changing the modifier entry for this function.
    function setAccessClearance(address account, uint access_level) external virtual max_level returns (bool) {

        require( access_level >= 0 && access_level <= MAX_CLEARANCE, "Admin: Invalid access level specified.");

        UAC[account].access = access_level;
        emit AccessSet( _msgSender(), account, access_level, block.timestamp);

        return true;
    }

    function toggleLevelLock(address account, bool toggle) external max_level returns (bool) {
        UAC[account].isLevelLocked = toggle;
        return true;
    }

    function level(uint _level) internal view {
        require( UAC[_msgSender()].access >= _level, "Insufficient access");
    }

    /// @dev downgrades an account's clearance by 1 level. Accounts below the required modifier clearance cannot modify access levels.
    // if an account is level locked, only max clearance can unlock it
    function downgradeAccess(address account) external virtual level3 returns (bool) { 
        
        bool callerUnlockPrivilege = (UAC[_msgSender()].access == MAX_CLEARANCE);

        if (UAC[account].access - 1 >= MIN_CLEARANCE) {

            if (UAC[account].isLevelLocked) {
                if (!callerUnlockPrivilege) { return false; }
            }
            UAC[account].access -= 1;
            return true;
        }
    }

    
    /// @dev upgrades an account's clearance by 1 level.
    function upgradeAccess(address account) external virtual max_level returns (bool) {

        bool callerUnlockPrivilege = (UAC[_msgSender()].access == MAX_CLEARANCE);
   
        if (UAC[account].access + 1 <= MAX_CLEARANCE) {

            if (UAC[account].isLevelLocked) {
                if (!callerUnlockPrivilege) { return false; }
            }
            UAC[account].access += 1;
            return true;
        } 
   
    }

    /** @dev Transfers ownership of the contract to a new account `newAdmin`. Can only be called by the current admin. Can be set to address(0),
     * which leaves the contract without an admin. It will not be possible to call `onlyAdmin` functions anymore.
     * NOTE: Renouncing ownership will leave the contract without an admin, thereby removing any functionality that is only available to the admin. 
     * Also may lose any tokens owned by the previous admin. */

    function reassignOwnership( address newAdmin, address certify ) external virtual onlyAdmin { 
        require( certify == address(0), "Super: Must confirm with 0x0.");
        admin = payable( newAdmin );
        emit OwnershipTransferred( admin, newAdmin );
    }

    // Locks the contract for owner for the amount of time entered
    function lock( uint time ) external virtual onlyAdmin {
        previousAdmin = admin;
        admin = payable(0);
        lockTime = block.timestamp + time;
        emit OwnershipTransferred( admin, address(0) );
    }

    // Unlocks the contract for owner when lockTime is exceeded.
    function unlock() external virtual {

        require( _msgSender() == previousAdmin, "You were not the owner.");
        require( block.timestamp > lockTime , "Contract is still locked.");

        admin = payable(previousAdmin);
        emit OwnershipTransferred( admin, previousAdmin );
    }

    // Returns time left until unlocking
    function getUnlockTime() external view returns (int) { 
        return int(lockTime) - int(block.timestamp);
    }

} // # End Administrator
