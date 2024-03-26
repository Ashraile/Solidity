/** SPDX-License-Identifier: GPL-3.0
    @author Jasper Wolf (https://github.com/Ashraile)
    @title test.sol
    @custom:version 3.0
*/


/// @dev `uint256` is the most gas-efficient value type in Solidity.
pragma solidity 0.8.24;

//import "./UniswapV2Suite.sol";

address payable constant NULL = payable(0);
address payable constant BURN = payable(address(57005));

uint256 constant MAX = type(uint).max;
uint256 constant TRUE = 2;
uint256 constant UNTRUE = 1;
uint256 constant FALSE = 0;


/// @dev Returns true if the contract supports the given interface. @custom:IID 0x01ffc9a7
interface IERC165 {
    function supportsInterface(bytes4 IID) external view returns (bool); 
}

interface IERC20 {
    event Approval (address indexed owner, address indexed spender, uint amount); 
    event Transfer (address indexed from, address indexed to, uint amount);
    function allowance( address owner, address spender ) external view returns (uint);
    function approve( address spender, uint amount ) external returns (bool);
    function balanceOf( address account ) external view returns (uint);
    function totalSupply() external view returns (uint);
    function transfer( address recipient, uint amount ) external returns (bool);
    function transferFrom( address sender, address recipient, uint amount ) external returns (bool);
}


/// @dev Interface for the optional metadata functions from the ERC20 standard. @custom:IID
interface IERC20Metadata is IERC20 {
    function decimals() external view returns (uint8);          /// @dev Returns the token decimals.
    function name() external view returns (string memory);      /// @dev Returns the token name.
    function symbol() external view returns (string memory);    /// @dev Returns the token symbol.
}


interface IERC20MetadataExtended is IERC20Metadata {
    function releaseDate() external view returns (uint40);
    function releaseSupply() external view returns (uint);
}


interface IERC721 is IERC165 {


}

/** @custom:credit Remco Bloemen (https://xn--2-umb.com/21/muldiv)
    @custom:improv Uniswap Labs 
    @custom:source OpenZeppelin (Math library)
    @custom:license MIT
*/
library Math {

    /** @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0. 
        Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits. */
    error MathOverflowedMulDiv();

    function mulDiv(uint x, uint y, uint d) internal pure returns (uint) {  unchecked  {

        // 512-bit multiply [prod1 prod0] = x*y. Compute the product mod 2^256 and mod 2^256 - 1, then use the Chinese Remainder Theorem to reconstruct the 512 bit result. 
        // The result is stored in two 256 variables such that product = prod1 * 2^256 + prod0. 

        uint prod0 = x * y; uint prod1; // (Least, Most) significant 256 bits of the product.
        assembly {
            let mm := mulmod(x, y, not(0))
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // 256 by 256 division
        if (prod1 == 0) { return prod0 / d; }
        // Solidity will revert if denominator == 0, unlike the div opcode on its own.
        // The surrounding unchecked block does not change this fact.
        /// @custom:ref https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.

        if (d <= prod1) { revert MathOverflowedMulDiv(); } // Make sure the result is less than 2^256. Also prevents denominator == 0.

        // 512 by 256 division
        uint remainder; // Make division exact by subtracting the remainder from [prod1 prod0].
        assembly {
            remainder := mulmod(x, y, d)    // Compute remainder using mulmod.
            prod1 := sub(prod1, gt(remainder, prod0)) // Subtract 256 bit number from 512 bit number.
            prod0 := sub(prod0, remainder)
        }

        uint twos = d & (0 - d);                      // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
        assembly {                                    /// @custom:ref https://cs.stackexchange.com/q/138556/92363.
            d := div(d, twos)                         // Divide denominator by twos.
            prod0 := div(prod0, twos)                 // Divide [prod1 prod0] by twos.
            twos := add(div(sub(0, twos), twos), 1)   // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
        }

        prod0 |= prod1 * twos; // Shift in bits from prod1 into prod0.

        // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such that denominator * inv = 1 mod 2^256.
        // Compute the inverse by starting with a seed that is correct for four bits. That is, denominator * inv = 1 mod 2^4.
        uint inv = (3 * d) ^ 2;

        inv *= 2 - d * inv; // inverse mod 2**8     ~   Use the Newton-Raphson iteration to improve the precision.
        inv *= 2 - d * inv; // inverse mod 2**16    ~   Thanks to Hensel's lifting lemma, this also works in modular arithmetic, doubling the correct bits in each step.
        inv *= 2 - d * inv; // inverse mod 2**32    ~   
        inv *= 2 - d * inv; // inverse mod 2**64    ~   Because the division is now exact we can divide by multiplying with the modular inverse of the denominator.
        inv *= 2 - d * inv; // inverse mod 2**128   ~   This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is less than 2^256,
        inv *= 2 - d * inv; // inverse mod 2**256   ~   this is the final result. We don't need to compute the high bits of the result and prod1 is no longer required.
 
        return prod0 * inv;
    }}
}

/**
 * @dev Implementation of the {IERC165} interface. Contracts may inherit from this and call {_registerInterface} to declare their support of an interface.
 * Derived contracts need only register support for their own interfaces; we register support for ERC165 itself here.
 */
abstract contract ERC165 is IERC165 {
    constructor() { 
        _registerInterface(0x01ffc9a7); // => bytes4(keccak256('supportsInterface(bytes4)'))
    }

    /// @dev See {IERC165-supportsInterface}. Time complexity O(1), guaranteed to always use less than 30 000 gas.
    mapping (bytes4 IID => bool) public supportsInterface;
    
    /// @dev Registers the contract as an implementer of an interface. Returns `false` on the invalid interface `0xffffffff`.
    function _registerInterface(bytes4 IID) internal virtual { 
        supportsInterface[IID] = (IID != 0xffffffff);
    }
}


abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) { return payable(msg.sender); }
    function _msgData() internal view virtual returns (bytes calldata) { return msg.data; }
}


/** @dev Contract module which provides an intermediate access control mechanism, where there is an account (an owner)
    that can be granted exclusive access to specific functions. By default, the owner account will be the one that deploys the contract.
    This can later be changed with {transferOwnership}. This module is used through inheritance. 
    It will make available the modifier `onlyOwner`, which can be applied to your functions to restrict their use to the owner.
    @custom:version 3.1
 */ 
abstract contract Ownable is Context {

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event AccessChanged(uint indexed newAccessLevel, uint indexed timestamp);

    error Unauthorized();

    constructor() payable {
        _transferOwnership(_msgSender()); // Initializes the contract setting the deployer as the initial owner.
    }

    address public owner;

    uint public sudo = 3; // Internal variable for tiered owner privileges.

    modifier onlyOwner virtual { _checkOwner(); _; }

    modifier access(uint tier) { 
        if (tier > sudo) { revert Unauthorized(); } 
        _;
    }
    modifier passcode(string calldata PIN) virtual {  // Reverts if PIN isn't the keccak256 hard-encoded hash.
        if (keccak256(abi.encode(PIN)) != 0x1a3de7f8fee736ca6a61818e30cd3f87f1f33473225476af28ae8c1a0786c7eb) { 
            revert Unauthorized();
        } _; 
    }

    function _checkOwner() private view {
        if (_msgSender() != owner || owner == address(0)) { revert Unauthorized(); }
    }

    function lowerOwnerAccessBy1() onlyOwner external { // Lowers access level for the owner. Once lowered it cannot be increased.
        if (sudo == 0) { return; } emit AccessChanged(--sudo, block.timestamp);
    }

    function _revokeOwnerPrivileges() private { 
        if (sudo == 0) { return; } sudo = 0; emit AccessChanged(0, block.timestamp);
    }

    function revokeOwnerPrivileges() onlyOwner external { _revokeOwnerPrivileges(); }
     
    /** @dev Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.
     * Will also leave any tokens owned, in possession of the previous owner.
     * Renouncing ownership will effectively leave the contract without an owner, thereby removing any functionality that is only available to the owner.
    */
    function transferOwnership(address payable newOwner, string calldata PIN) onlyOwner() passcode(PIN) external {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) private {
        address prevOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(prevOwner, newOwner);
        if (newOwner == address(0)) { 
            _revokeOwnerPrivileges();
        }
    }
}


interface IERC20CustomErrors {
    error ERC20InvalidApproval();
    error ERC20InvalidBalance();
    error ERC20InsufficientAllowance(uint attempted, uint allowed);
    error ERC20InsufficientBalance();
    error ERC20InvalidTransfer();
}



/** @author Jasper Wolf (https://www.github.com/Ashraile)  Requires Solidity 0.8+
    @dev Advanced customizable ERC20 (BEP20) token generation framework. @custom:ref https://github.com/bnb-chain/BEPs/blob/master/BEPs/BEP20.md
*/
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20CustomErrors, Ownable {

    constructor(_init memory Token) {  unchecked  {

        (_name, _symbol, _version, decimals) = (Token.name, Token.symbol, Token.version, Token.decimals);

        releaseDate = uint40(block.timestamp);
        releaseSupply = _totalSupply = _balances[_msgSender()] = (Token.totalSupply * (10 ** decimals));

        emit Transfer(address(0), _msgSender(), _totalSupply);

    }}

    struct _init { string name; string symbol; string version; uint8 decimals; uint256 totalSupply; }

    mapping (address => uint) internal _balances;
    mapping (address holder => mapping(address spender => uint)) internal _allowances;

    uint256 _totalSupply;

    /////////////////////////////////// Public Virtual Implementation Functions /////////////////////////////////////

    uint8   public immutable decimals;       /// @dev See {ERC20-decimals}.
    uint40  public immutable releaseDate;    /// @dev See {ERC21-releaseDate}.
    uint256 public immutable releaseSupply;  /// @dev See {ERC21-releaseSupply}.

    string private _name;
    string private _symbol;
    string private _version;

    function name() external view virtual returns (string memory) { return _name; }
    function symbol() external view virtual returns (string memory) { return _symbol; }
    function version() external view virtual returns (string memory) { return _version; }

 // function getOwner() public view virtual returns (address payable) { return payable(owner); }                    /// @dev Uncomment for BNB Chain.
    function totalSupply() public view virtual returns (uint) { return _totalSupply; }                              /// @dev See {ERC20-totalSupply}.                            

    function allowance(address holder, address spender) public view virtual returns (uint) {                        /// @dev See {ERC20-allowance}.
        return _allowances[holder][spender];
    }

    function balanceOf(address account) public view virtual returns (uint) {                                        /// @dev See {ERC20-balanceOf}.
        return _balances[account]; 
    }

    function transfer(address to, uint amount) public virtual returns (bool) {                                      /// @dev See {ERC20-transfer}.
        // return _transfer(_msgSender(), to, amount, false);
        _transfer(_msgSender(), to, amount, false); 
        return true; 
    }
    
    function transferFrom(address from, address to, uint amount) public virtual returns (bool) {  unchecked  {      /// @dev See {ERC20-transferFrom}. [UNCHECKED]
        address self = _msgSender();
        uint spendLimit = allowance(from, self); // Default allowance is 0.
        if (amount > spendLimit) { 
            revert ERC20InsufficientAllowance({ attempted: amount, allowed: spendLimit });
        }
        _approve(from, self, spendLimit - amount);
        _transfer(from, to, amount, false);
        return true;
    }}

    function approve(address spender, uint amount) public virtual returns (bool) {                                  /// @dev See {ERC20-approve}.
        // return _approve(_msgSender(), spender, amount);
        _approve(_msgSender(), spender, amount); 
        return true;
    }

    function decreaseAllowance(address spender, uint subtractedValue) public virtual returns (bool decreased) {
        _approve(_msgSender(), spender, allowance(_msgSender(),spender) - subtractedValue); return true;
    }

    function increaseAllowance(address spender, uint addedValue) public virtual returns (bool increased) {
        _approve(_msgSender(), spender, allowance(_msgSender(),spender) + addedValue); return true;
    }

    ////////////////////////////////// Internal Virtual Implementation Functions ////////////////////////////////////

    function _beforeTokenTransfer(address from, address to, uint amount) internal virtual {}
    function _afterTokenTransfer (address from, address to, uint amount) internal virtual {}

    function _approve(address holder, address spender, uint amount) internal virtual {
        if (spender == NULL || spender == BURN || holder == NULL || holder == BURN) {
            revert ERC20InvalidApproval();
        }
        _allowances[holder][spender] = amount;
        emit Approval(holder, spender, amount);   
    }
    
    function _transfer(address from, address to, uint amount) internal virtual { _transfer(from, to, amount, false); }
    function _transfer(address from, address to, uint amount, bool /* isTaxExempt */) internal virtual {
        _beforeTokenTransfer(from, to, amount);

        _balances[from] -= amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
        _afterTokenTransfer(from, to, amount);
    }

    function _transferExempt(address from, address to, uint amount) internal virtual { 
        _transfer(from, to, amount, true);
    }
}


/** @custom:origin Safemoon.sol @custom:license MIT @custom:improv Jasper Wolf (https://www.github.com/Ashraile)
    @custom:version 4.0 @dev Contract module that enables a token reflection system. @custom:requires 0.8+ */

pragma solidity ^0.8.24;

abstract contract ERC20Reflectable is ERC20 {

    constructor() {
        _tTotal = super.totalSupply(); // Need the previous total supply before overriding `totalSupply()` because _rTotal at this point is 0.
        _rTotal = (type(uint).max - (type(uint).max % _tTotal)); 
        _rOwned[_msgSender()] = _rTotal; // allocate initial supply to deployer
    }

    /// NOTE: An earlier implementation combined the latter mappings into a struct but it looked ugly as hell and actually cost more gas after deployment.
    /// NOTE: We simply ignore the inherited `_balances` mapping, but use the inherited `_allowances` mapping.

    mapping (address => uint) internal _rOwned;
    mapping (address => uint) internal _tOwned;
    mapping (address => bool) internal _isTaxExempt;
    mapping (address => bool) internal _isExcluded;

    address[] internal rExcluded;

    uint internal _rTotal; 
    uint internal _tTotal;
    uint internal _reflectionTaxPercent = 5;
    
    function balanceOf(address account) public view virtual override returns (uint) {
        return _isExcluded[account] ? _tOwned[account] : tokenFromReflection(_rOwned[account]);
    }

    function _transfer(address from, address to, uint amount, bool isTaxExempt) internal virtual override {
        _beforeTokenTransfer(from, to, amount);
        _transferAllCases   (from, to, amount, (isTaxExempt || _isTaxExempt[from] || _isTaxExempt[to]));
        _afterTokenTransfer (from, to, amount);
    }

    /// NOTE: Requires Solidity 0.8+.
    function _sendTokensSupportingFeeOnTransfer(
        address from, 
        address to, 
        uint amount,         // amount to deduct from sender
        uint amountAfterFees // amount to send to receiver
    ) 
    internal 
    virtual 
    returns (uint currentRate) { 
        // assert(amountAfterFees <= amount);
        // NOTE: R values are always T Values * currentRate.
        currentRate = _getRate();

        _rOwned[from] -= (amount * currentRate);
        _rOwned[to] += (amountAfterFees * currentRate);

        if (_isExcluded[from]) {
            _tOwned[from] -= amount;
        }
        if (_isExcluded[to]) {
            _tOwned[to] += amountAfterFees;
        }
        emit Transfer(from, to, amountAfterFees);
    }

    /** @dev Combines Safemoon's `_transferStandard()`, `_transferFromExcluded()`, `_transferToExcluded()`, and `_transferBothExcluded()` into one function.
        NOTE: Requires Solidity 0.8+. Do NOT enclose in unchecked bloc. Will auto revert if insufficient funds.
    */
    function _transferAllCases(address from, address to, uint amount, bool isTaxExempt) internal virtual {
        uint tFee; // 0
        if (!isTaxExempt) {
            tFee = (amount * _reflectionTaxPercent) / 100;
        }
        uint currentRate = _sendTokensSupportingFeeOnTransfer(from, to, amount, (amount - tFee));
        if (!isTaxExempt) {
            _reflect(tFee * currentRate);
        }
    }
    
    ///////////////////////////////////// OnlyOwner functions ///////////////////////////////////////

    function setReflectionTaxPercent(uint percent) public virtual onlyOwner {
        _reflectionTaxPercent = percent;
    }

    function setTaxExemptStatus(address account, bool isTaxExempt) public virtual onlyOwner { 
        _isTaxExempt[account] = isTaxExempt;
    }

    /** NOTE: This function is not unitarily bidirectional. Including an account changes the existing reflections for all accounts,
        whereas excluding an account merely prevents an account from receiving future rewards, keeping other balances the same.
        TRUE: includeInReward, FALSE: excludeFromReward
    */
    function setRewardStatus(address account, bool include) public virtual onlyOwner {  unchecked  {
        require(
            (include == _isExcluded[account]), string.concat("Account is already ", (include ? "in":"ex"),"cluded")
        );
        if (include) { 
            uint len = rExcluded.length; 
            for (uint i; i < len; ++i) {
                if (rExcluded[i] == account) {
                    rExcluded[i] = rExcluded[len - 1]; // swap with last and pop
                    rExcluded.pop();
                    _tOwned[account] = 0; 
                   _isExcluded[account] = false;
                   break;
                }
            }
        } else { 
            // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
            if (_rOwned[account] > 0) { 
                _tOwned[account] = tokenFromReflection(_rOwned[account]);
            }
            rExcluded.push(account); 
            _isExcluded[account] = true;
        }
    }}

    // function excludeFromReward(address account) public virtual onlyOwner { setRewardStatus(account, false); }
    // function includeInReward(address account) external virtual onlyOwner { setRewardStatus(account, true); }

    //////////////////////////////////////// Helper functions /////////////////////////////////////////////////////

    // Gets tokens owned from a reflection balance.
    function tokenFromReflection(uint rAmount) internal view virtual returns (uint tOwned) {
        if (rAmount > _rTotal) { revert ERC20InvalidBalance(); } 
        return rAmount / _getRate();
    }

    function _getRate() internal view virtual returns (uint) {
        (uint rSupply, uint tSupply) = _getCurrentSupply(); 
        return (rSupply / tSupply);
    }

    function _getCurrentSupply() internal view virtual returns (uint rSupply, uint tSupply) {  unchecked  {

        (rSupply, tSupply) = (_rTotal, _tTotal);

        uint len = rExcluded.length; uint rOwned; uint tOwned; address account; 
        for (uint i; i<len; ++i) { 
            account = rExcluded[i];
            (rOwned, tOwned) = (_rOwned[account], _tOwned[account]);
            if (rOwned > rSupply || tOwned > tSupply) { return (_rTotal, _tTotal); }
            rSupply -= rOwned; 
            tSupply -= tOwned;
        }
        return (rSupply < (_rTotal / _tTotal)) ? (_rTotal, _tTotal) : (rSupply, tSupply);
    }}

    function _reflect(uint rAmount) internal virtual { _rTotal -= rAmount; }

    // function reflectionFromToken(uint tAmount, bool deductTransferFee) public view virtual returns (uint rOwned) {}
}

function TestToken is ERC20Reflectable, ERC165 {
    constructor() payable
        ERC20(
            _init({
                name: "TESTTOKEN",
                symbol: "TEST",
                version: "4.0",
                decimals: 18,
                totalSupply: 1e6
            })
        )
    {
        setRewardStatus(address(this), false); // This contract does not receive reflections
        setReflectionTaxPercent(10); // reflection on buys or sell
    }
    receive() external payable {}
}
    
