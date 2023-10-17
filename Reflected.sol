
/// @author Jasper Wolf (https://www.github.com/Ashraile)
/// @custom:license MIT
/// @dev Contract module that enables a token reflection system. Vastly simpler than that Safemoon gibberish.
/// Inherits ./BEP21.sol

/** @custom:credit Remco Bloemen (https://xn--2-umb.com/21/muldiv)
    @custom:improv Uniswap Labs 
    @custom:source OpenZeppelin (Math library)
    @custom:license MIT
*/
library Math {

    /** @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0. 
        Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits. 
    */
    error MathOverflowedMulDiv();

    function mulDiv(uint x, uint y, uint d) internal pure returns (uint) { 
      unchecked {

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

        inv *= 2 - d * inv; // inverse mod 2**8      ~    Use the Newton-Raphson iteration to improve the precision.
        inv *= 2 - d * inv; // inverse mod 2**16     ~    Thanks to Hensel's lifting lemma, this also works in modular arithmetic,
        inv *= 2 - d * inv; // inverse mod 2**32     ~    doubling the correct bits in each step.
        inv *= 2 - d * inv; // inverse mod 2**64
        inv *= 2 - d * inv; // inverse mod 2**128
        inv *= 2 - d * inv; // inverse mod 2**256

        // Because the division is now exact we can divide by multiplying with the modular inverse of the denominator.
        // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is less than 2^256,
        // this is the final result. We don't need to compute the high bits of the result and prod1 is no longer required.
        return prod0 * inv;
      }
    }
}

abstract contract Reflected is BEP21 {

    using Math for uint;

    constructor() {}

    uint private constant MAX = ~uint(0); // 2**256 - 1

    address[] private rExcluded; 
    
    // mapping (address => bool) isReflectionExcluded;

    uint internal ReflectionPool; // All tokens that will be redistributed among holders

    /*
    * @dev [Private | Internal] Overrides inherited `_balanceOf()`.
    */ 
    function _balanceOf(address account) internal view virtual override returns (uint) {
        return addresses[account].isReflectionExcluded ? addresses[account].balance : reflectTokenBalance(addresses[account].balance);
    }

    /*
    * @dev Determines if an account is excluded from reflections.
    */
    function _isReflectionExcluded(address account) internal view virtual returns (bool isReflectionExcluded) { 
        return addresses[account].isReflectionExcluded;
    }

    /** @dev [Private | Internal] Returns all unburned tokens owned by reflection excluded accounts. Current gas cost (remix): ~20,000.
        NOTE: If there are no excluded accounts, the majority of reflections will be owned by the owner and burn accounts, 
        thereby minimizing the rROI for token holders. By excluding certain accounts as needed, investor profits are maximized.
        
        NOTE: This function's gas cost can be further optimized in 2 ways: 
        1. Converting it to assembly. (+20% savings). 
        2. Setting a global uint `ReflectionExcludedBalances` and updating the collective balance as required within `_transfer()`. (+90% savings). 
            This scenario obviates maintaining rExcluded[].

        Limitations: rExcluded[] should be limited to owner, burn, and DEXes (Uniswap, Pancakeswap) to prevent O(n) gas cost per transaction.
        CEXes (Kraken, Binance) SHOULD receive reflections for delegation towards their respective sub-accounts.
    */
    function getExcludedSupply() public view virtual returns (uint ReflectionExcludedTokens) {
        uint i; uint len = rExcluded.length;
        unchecked {
            for (; i<len;) {
                if (rExcluded[i] != BURN) { // While the BURN account is indeed excluded, it also reduces total supply, so we skip this balance to avoid double entry.
                    ReflectionExcludedTokens += addresses[rExcluded[i]].balance;
                } ++i;
            }
            return ReflectionExcludedTokens;
        }
    }

    /// @dev Returns all tokens not owned by reflection excluded accounts.
    function getIncludedSupply() public view virtual returns (uint) { 
        unchecked {
            return totalSupply - getExcludedSupply(); // assert(totalSupply >= getExcludedSupply());
        }
    }

    /// @dev Returns the reflection pool.
    function getReflectionPool() public view returns (uint ReflectedTokens) { return ReflectionPool; }


    /** @dev [Private] Returns an account's balance combined with applied reflections. Accurate to 1 shard
        uint MarketShareAsUINT = tBalance.mulDiv(MAX_ACCURACY, supply);
        uint Reflections = MarketShareAsUINT.mulDiv(ReflectionPool, MAX_ACCURACY); 
     */
    function reflectTokenBalance(uint tBalance) public view virtual returns (uint) {
        uint supply = getIncludedSupply(); 
        if (supply == 0 || tBalance == 0) { return tBalance; }
        unchecked {
            uint MAX_ACCURACY = MAX / tBalance; // accuracy multiplier
            uint rBalance = tBalance.mulDiv(MAX_ACCURACY, supply).mulDiv(ReflectionPool, MAX_ACCURACY);
            return tBalance + rBalance;
        }
    }


    /** @dev [Private] Returns an account's balance decombined from applied reflections. (reflectTokenBalance => value <= unreflectTokenBalance)
        Example numbers working backwards: TotalCurrentSupply: 100000, ReflectionPool: 20000, PostReflectionBalance: 884.4, PreReflectionBalance: `x`

        1. x + [ MarketShareAsUINT * ReflectionPool) ] = PostReflectionBalance
        2. x + [ (x / TotalCurrentSupply) * ReflectionPool ] = PostReflectionBalance
        3. x + [ (x / 100000) * 20000 ] = 884.4
        4. x + [ (20000x) / 100000 ] = 884.4
        5. 100000x + 20000x = 884.4 * 100000
        6. 120000x = 88440000 ==> x = 88440000 / 120000 ==> x = 737

        Solving for `x` from step 5:

        `x` = (PostReflectionBalance * TotalCurrentSupply) / (TotalCurrentSupply + ReflectionPool)
        `x`  = (884.4 * 100000) / (100000 + 20000)
        `x`  = 88440000 / 120000 => 737
     */
    function unreflectTokenBalance(uint cBalance) public view virtual returns (uint) { 
        uint supply = getIncludedSupply(); 
        if (supply == 0 || cBalance == 0) { return cBalance; }  
        unchecked {
            uint step1 = cBalance * supply;
            uint MAX_ACCURACY = MAX / step1;
            uint step2 = step1.mulDiv(MAX_ACCURACY, supply + ReflectionPool); // assert(supply + ReflectionPool > 0);
            uint modulo = step2 % MAX_ACCURACY;

            return (step2 / MAX_ACCURACY) + ((modulo != 0) ? 1 : 0); // if division is inexact, add 1
        }
    }


    // If you want the burn account to receive reflections:
    // function totalSupply2() public view returns (uint) { return totalSupply - _balanceOf(BURN); }

    function addReflections(uint reflections) public onlyOwner virtual returns (bool) { ReflectionPool += reflections; return true; }
    function setReflections(uint reflections) public onlyOwner virtual returns (bool) { ReflectionPool = reflections; return true; }


    /** @notice While excluded, any reflections the account has are now erased. This increases rBalance for all other reflected accounts.
     */
    function _excludeFromReflections(address account) public onlyOwner access(2) returns (bool success) {   
        require(addresses[account].isReflectionExcluded == false, "Account is already excluded.");

        addresses[account].isReflectionExcluded = true;
        rExcluded.push(account);
        return true;
    }

    /** @notice Including a balance decreases rBalance for all other reflected accounts.
    */
    function _includeInReflections(address account) public onlyOwner access(2) returns (bool success) {
        require(addresses[account].isReflectionExcluded == true, "Account is already not excluded.");

        uint i; uint len = rExcluded.length; 
        unchecked { // remove address from rExcluded[]
            for (; i<len;) {
                if (account == rExcluded[i]) {
                    rExcluded[i] = rExcluded[len-1]; // swaps places with last element in the array
                    rExcluded.pop(); 

                    addresses[account].isReflectionExcluded = false;
                    return true;
                } ++i;
            }
        }
    }

    function _excludeFromReflectionsPreservingBalance(address account) public onlyOwner access(1) returns (bool success) {}
    function _includeInReflectionsPreservingBalance(address account) public onlyOwner access(1) returns (bool success) {}


    /// @dev Function to handle reflection fees on transfer.
    function _takeAndHandleFees(uint amount) internal virtual returns (uint remainder) {

        uint ReflectionFee = amount.mulDiv(1,100); // Example 1% Fee. 
        
        // Subtract reflection fee from transaction amount.
        amount -= ReflectionFee;

        // Add the amount to the reflection pool.
        ReflectionPool += ReflectionFee;

        return amount;
    }
    function _takeAndHandleFees(uint amount, uint senderBalance) internal virtual returns (uint remainder) {}


    function _afterTokenTransfer (address from, address to, uint Lunari) internal virtual override returns (bool) {}
    function _beforeTokenTransfer(address from, address to, uint Lunari) internal virtual override returns (uint) {

        if (from == address(0) || to == address(0) || from == BURN) { 
            revert InvalidTransfer(); // However, allow direct transfers to the BURN address.
        }
    }

    /*
    * @dev Reflection implementation of `transfer()`. Can be overridden.
    */
    function _transfer(address from, address to, uint amount, bool ForceFeeExemption) internal virtual override returns (bool) {
        
        _beforeTokenTransfer(from, to, amount);

        uint senderBalance = _balanceOf(from); // get the sender balance including reflections. (if applicable).

        if (amount > senderBalance) { revert InsufficientBalance({ attempted: amount, available: senderBalance }); }

        /** @notice First update the sender balance. 
            NOTE: If the address is reflection excluded, rBalance is always 0. We can subtract the transfer amount from `senderBalance` as is.
            NOTE: Otherwise, `senderBalance` is reflected, so we must solve for the unreflected token balance which, after applicable reflections,
            will equal the interim reflected balance. "Taking out" the reflections so they won't compound upon themselves for every transfer.
        */
        unchecked {
            // First update the sender balance.
            addresses[from].balance = _isReflectionExcluded(from) ? (senderBalance - amount) : unreflectTokenBalance(senderBalance - amount);
            
            // Subtract and allocate the fees as needed from the transfer amount.
            amount = _takeAndHandleFees(amount);

            // Then update the recipient balance.
            addresses[to].balance += amount; // If reflections apply to new recipient balance, they are calculated by default at transfer start.
        }

        emit Transfer(from, to, amount);
        _afterTokenTransfer(from, to, amount);
        return true;
    }

}

}
