/// SPDX-License-Identifier: MIT
/**
    @author Jasper Wolf (https://github.com/Ashraile)
    @title BEP-21.sol
    @dev An advanced extensible, and highly customizable token generator boilerplate.
*/

pragma solidity 0.8.20;

/** @dev Interface of the BEP20 standard. @custom:ref https://github.com/bnb-chain/BEPs/blob/master/BEPs/BEP20.md
*/
interface IBEP20 {

    event Approval (address indexed owner, address indexed spender, uint Lunari); 
    event Transfer (address indexed from, address indexed to, uint Lunari);

    function decimals() external view returns (uint8);             /// @dev Returns the token decimals.
    function getOwner() external view returns (address payable);   /// @dev Returns the BEP-20 token owner.
    function name()     external view returns (string memory);     /// @dev Returns the token name.
    function symbol()   external view returns (string memory);     /// @dev Returns the token symbol.
    function totalSupply() external view returns (uint);           /// @dev Returns the (current) amount of unburned tokens in existence.
    
    function allowance(address holder, address spender) external view returns (uint remaining);
    function approve(address spender, uint Lunari) external returns (bool success);
    function balanceOf(address account) external view returns (uint Lunari);     /// @dev Returns the balance in Lunari of a given address.
    function transfer(address to, uint Lunari) external returns (bool success);
    function transferFrom(address from, address to, uint Lunari) external returns (bool success);

}

/** @dev The BEP20 standard, extended. */
interface IBEP21 is IBEP20 {

    error InsufficientBalance(uint attempted, uint available);
    error InsufficientAllowance(uint attempted, uint allowance);
    error InvalidApproval();
    error InvalidTransfer();

    event Burn(address indexed from, uint indexed amount);       /// @dev Default burn address is 0x000000000000000000000000000000000000dEaD.

    struct TokenData { 
        bytes32 name;
        bytes32 symbol; 
        bytes32 version; 
        uint8 decimals; 
        uint releaseDate; 
        uint releaseSupply;
    }

    function burn(uint Lunari) external returns (bool success);  /// @dev Burns the specified amount from caller's account. Reduces total supply.

    function getThis() external view returns (address payable);  /// @dev Returns the token contract address `address(this)`. {immutable}

    function releaseDate() external view returns (uint);         /// @dev Returns the token blockchain genesis date in UNIX epoch time. {immutable}

    function releaseSupply() external view returns (uint);       /// @dev Returns the initial token supply at creation, with decimals. {immutable | constant}

    function version() external view returns (string memory);    /// @dev Returns the token contract build version.

}

/** @dev Contract module which provides an intermediate access control mechanism, where there is an account (an owner)
    that can be granted exclusive access to specific functions. By default, the owner account will be the one that deploys the contract.
    This can later be changed with {transferOwnership}. This module is used through inheritance. 
    It will make available the modifier `onlyOwner`, which can be applied to your functions to restrict their use to the owner.
 */ 
abstract contract Admin is Context {

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event AccessLowered(address indexed owner, uint8 indexed access, uint timestamp);

    error InsufficientAccess();
    error Unauthorized();
    error IncorrectPIN();

    /// @dev Initializes the contract setting the deployer as the initial owner.
    constructor() payable { 
        _transferOwnership(_msgSender());
    }

    address payable public owner; // => owner()

    /// @dev Internal variable for tiered owner privileges.
    uint8 public ownerRoot = 3;

    /// @dev Throws if called by any account other than the owner, or if owner has renounced ownership.
    modifier onlyOwner {
        if (_msgSender() != owner || owner == address(0)) { revert Unauthorized(); }
        _;
     }
    
    /// @dev Throws if PIN does not match the keccak256 encoded hash (hardcoded by owner before deployment).
    modifier passcode(string calldata PIN) {
        if (keccak256(abi.encode(PIN)) != 0x1a3de7f8fee736ca6a61818e30cd3f87f1f33473225476af28ae8c1a0786c7eb) { 
            revert IncorrectPIN();
        }
        _;
    }

    /// @dev Lowers access level for the owner. Once lowered it cannot be increased.
    function lowerOwnerAccess() external onlyOwner returns (uint8) {
        emit AccessLowered(owner, ownerRoot-1, block.timestamp);
        return --ownerRoot;
    }

    /** @dev Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.
     * Will also leave any tokens owned, in possession of the previous owner.
     * Note: transferring to a dead address will leave the contract without an owner (thereby renouncing ownership).
     * Renouncing ownership will effectively leave the contract without an owner, thereby removing any functionality that is only available to the owner.
    */
    function transferOwnership(address newOwner, string calldata PIN) passcode(PIN) external onlyOwner {
        _transferOwnership(newOwner);
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`). Internal function without access restriction.
    function _transferOwnership(address newOwner) private {
        address oldOwner = payable(owner); 
        owner = payable(newOwner);
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/** @custom:source OpenZeppelin (ReentrancyGuard.sol), with minor edits. 
    @custom:license MIT
    @dev Contract module that helps prevent reentrant calls to a function. Inheriting from `Idempotent` will make the {idempotent} modifier available, 
    which can be applied to functions to make sure there are no nested (reentrant) calls to them.
*/
abstract contract Idempotent {

    constructor() { status = NOT_ENTERED; }

    // Booleans are more expensive than uint256 or any type that takes up a full word because each write operation
    // emits an extra SLOAD to first read the slot's contents, replace the bits taken up by the boolean, and then write back.
    // This is the compiler's defense against contract upgrades and pointer aliasing, and it cannot be disabled.

    uint private constant NOT_ENTERED = 1; // Setting to 0 increases gas cost back to a boolean.
    uint private constant ENTERED = 2;
    uint private status; 

    error NoReentry(); // Custom errors are cheaper in gas than require(condition, string)
    
    modifier idempotent {

        if (status == ENTERED) { revert NoReentry(); }
        status = ENTERED; // Any calls to {idempotent} after this point will fail.
        _; 
        status = NOT_ENTERED; /// By storing the original value once again, a refund is triggered. See @custom:ref https://eips.ethereum.org/EIPS/eip-2200
    }
}

/** @author Jasper Wolf (https://www.github.com/Ashraile)
    @dev Advanced customizable BEP20 token generation framework.
*/
abstract contract BEP21 is IBEP21, Admin, Idempotent {
    
    /// @dev Initializes the token contract metadata via child constructor.
    constructor(TokenData memory Token) {
  
        (_name, _symbol, _version, decimals) = (Token.name, Token.symbol, Token.version, Token.decimals);
        (releaseDate, releaseSupply) = (Token.releaseDate, Token.releaseSupply);

        addresses[owner].balance = totalSupply = releaseSupply;
        emit Transfer(NULL, owner, totalSupply);

        delete Token; 
    }

    /// @dev Extensible struct allows easy integration with custom token implementations.
    struct Account {
        mapping (address => uint) allowances;
        uint balance;
        bool isBlacklisted;
        bool isExchange;
        bool isReflectionExcluded;
        bool isTaxExempt;
    }

    mapping (address => Account) internal addresses;

    /** @custom:ref https://docs.soliditylang.org/en/v0.8.21/contracts.html#getter-functions
        NOTE: The Solidity compiler automatically generates external view functions for public variables.
     *  NOTE: Solidity ~0.8.20 does not support immutable strings, so bytes32 is used as a workaround.
     *  NOTE: Encoding immutable bytes32 loses ~200 gas compared to `string public constant name = {name}`, but saves 2000 runtime gas over regular implementations,
     *  and allows for dynamic customization in child constructor. */

    address payable internal constant NULL = payable(0);
    address payable internal constant BURN = payable(0x000000000000000000000000000000000000dEaD);
    
    bytes32 private immutable _name; 
    bytes32 private immutable _symbol;
    bytes32 private immutable _version;

    uint8 public immutable decimals;      // => decimals()

    uint public immutable releaseDate;    // => releaseDate()
    uint public immutable releaseSupply;  // => releaseSupply()

    uint public totalSupply;              // => totalSupply()

    /// @dev See {BEP20-name}.
    function name() external view returns (string memory) { return string(abi.encodePacked(_name)); }

    /// @dev See {BEP20-symbol}.
    function symbol() external view returns (string memory) { return string(abi.encodePacked(_symbol)); } 

    /// @dev See {IBEP21-version}.
    function version() external view returns (string memory) { return string(abi.encodePacked(_version)); } 

    /// @dev See {BEP20-allowance}.
    function allowance(address owner, address spender) external view returns (uint remaining) {
        return addresses[owner].allowances[spender];
    }

    /// @dev See {BEP20-approve}.
    function approve(address spender, uint limit) external returns (bool) { 
        return _approve( _msgSender(), spender, limit );
    }

    /// @dev See {BEP20-balanceOf}.
    function balanceOf(address account) external view returns (uint Lunari) {
        return _balanceOf(account);
    }

    /// @dev See {IBEP21-burn}.
    function burn(uint Lunari) external idempotent returns (bool) {
        return _transfer(_msgSender(), BURN, Lunari, true);
    }

    /// @dev Atomic approval decrease. Defacto standard.
    function decreaseAllowance(address spender, uint subtractedValue) external virtual returns (bool) {
        address sender = _msgSender();
        return _approve(sender, spender, (addresses[sender].allowances[spender] - subtractedValue)); 
    }

    /// @dev Atomic approval increase. Defacto standard.
    function increaseAllowance(address spender, uint addedValue) external virtual returns (bool) {
        address sender = _msgSender();
        return _approve(sender, spender, (addresses[sender].allowances[spender] + addedValue));
    }

    /// @dev See {BEP20-getOwner}.
    function getOwner() external view returns (address payable) { 
        return payable(owner); 
    } 
    
    /// @dev See {IBEP21-getThis}.
    function getThis() public override view returns (address payable) {
        return payable(address(this));
    }

    /// @dev See {BEP20-transfer}.
    function transfer(address to, uint Lunari) external idempotent returns (bool) { 
        return _transfer(_msgSender(), to, Lunari, false); 
    }

    /// @dev See {BEP20-transferFrom}.
    function transferFrom(address from, address to, uint Lunari) external idempotent returns (bool) {
        address sender = _msgSender();
        uint limit = addresses[from].allowances[sender]; // An account can only spend the allowance delegated to it. Default allowance is 0.
        if (Lunari > limit) {
            revert InsufficientAllowance({ attempted: Lunari, allowance: limit });
        }
        unchecked { 
            _approve(from, sender, (limit - Lunari)); // decreaseAllowance(from, Lunari);
        }
        return _transfer(from, to, Lunari, false);
    }
    
    /***************************   Internal Virtual Implementation Functions  ***************************/

    function _afterTokenTransfer (address from, address to, uint Lunari) internal virtual returns (bool) {}
    function _beforeTokenTransfer(address from, address to, uint Lunari) internal virtual returns (uint) {} // bool

    /// @dev Internal implementation of `_approve()`. Can be overridden.
    function _approve(address holder, address spender, uint Lunari) internal virtual returns (bool) {

        if (holder == NULL || holder == BURN || spender == NULL || spender == BURN) { revert InvalidApproval(); }
        addresses[holder].allowances[spender] = Lunari;
        emit Approval(holder, spender, Lunari);   
        return true;
    }

    /// @dev Internal implementation of `_balanceOf()`. Can be overridden.
    function _balanceOf(address account) internal view virtual returns (uint) { 
        return addresses[account].balance;
    }

    /// @dev Returns a balance with decimals from one without decimals. Can be overridden.
    function _pow(uint x, uint _decimals) internal pure virtual returns (uint) { 
        unchecked { return x * (10 ** _decimals); }
    }

    /// @dev Internal implementation of `_transfer()`. Can be overridden.
    function _transfer(address from, address to, uint Lunari, bool ForceFeeExemption) internal virtual returns (bool) {

        _beforeTokenTransfer(from, to, Lunari);

        if (from == NULL || to == NULL || from == BURN) { revert InvalidTransfer(); } // Allow direct transfers to the BURN address.

        uint senderBalance = addresses[from].balance;

        if (Lunari > senderBalance) {
            revert InsufficientBalance({ attempted: Lunari, available: senderBalance });
        }
        unchecked { addresses[from].balance = (senderBalance - Lunari); }

        addresses[to].balance += Lunari;
        emit Transfer(from, to, Lunari);

        _afterTokenTransfer(from, to, Lunari);
        return true;
    }
}


contract YourToken is BEP21 {

    constructor() payable BEP21(
        TokenData({
            name: "YourToken",
            symbol: "YTC",
            version: "1.2.71",
            decimals: 18,
            releaseDate: block.timestamp,
            releaseSupply: _pow(1e11, 18)
        })
    ) {

    }
}
