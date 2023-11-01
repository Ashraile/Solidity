
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

error InvalidBalance();

/** @custom:origin Safemoon.sol 
 *  @custom:improv Jasper Wolf (https://www.github.com/Ashraile)
 *  @custom:license MIT
 * @dev Contract module that enables a token reflection system. 
 */
abstract contract Reflectable is BEP21 {

    using Math for uint;

    uint internal constant MAX = type(uint).max;

    constructor() payable {
        _tTotal = super.totalSupply(); /// Need the previous total supply before overriding totalSupply() because rTotal at this point is 0.
        _rTotal = (MAX - (MAX % _tTotal)); 

        Accounts[_msgSender()].rOwned = _rTotal; 
    }
    
    // To receive ETH (BNB) from router when swapping
    receive() external payable {}

    /// @dev Extensible struct allows easy integration with custom token implementations.
    struct Account {
        uint rOwned;
        uint tOwned;
        bool isBlacklisted;
        bool isExchange;
        bool isExcluded;
        bool isTaxExempt;
        mapping (address => uint) allowances;
    }

    struct TransferValues {
        uint tTransferAmount; // uint tAmount;
        uint tFee;
        uint tBurn;
        uint tLiquidity;
        uint rAmount;
        uint rTransferAmount;
        uint rFee;
        uint rBurn; // uint rLiquidity;
    }

    struct Fees { 
        Ratio ReflectionTax; 
        Ratio LiquidityTax; 
        Ratio BurnTax;
    } // ufixed128x18 ReflectionTax; 😢

    struct Ratio { uint N; uint D; }

    mapping (address => Account) internal Accounts;

    address[] internal rExcluded;
    
    uint public _rTotal;
    uint public _tTotal;
    uint public totalFees;
    // uint private TAX_DENOMINATOR = 1e7;

    bool useDefaultFees = true;

    Fees public defaultFees;


    function allowance(address holder, address spender) public view virtual override returns (uint remaining) {
        return Accounts[holder].allowances[spender]; // allowances[holder][spender]
    }

    function balanceOf(address account) public view virtual override returns (uint Lunari) {
        return Accounts[account].isExcluded ? Accounts[account].tOwned : tokenFromReflection(Accounts[account].rOwned);
    }

    function totalSupply() public view virtual override returns (uint Lunari) {
        return releaseSupply - balanceOf(BURN);
    }

    function _approve(address holder, address spender, uint limit) internal virtual override returns (bool) { 
        if (holder == NULL || holder == BURN || spender == NULL || spender == BURN) { revert InvalidApproval(); }
        Accounts[holder].allowances[spender] = limit; 
        emit Approval(holder, spender, limit); 
        return true;
    }

    function setReflectionTax(uint rnum) public onlyOwner returns (bool success) {
        defaultFees.ReflectionTax.N = rnum; return true;
    }

    function setTaxExemptStatus(address account, bool isTaxExempt) public virtual onlyOwner returns (bool success) {
        Accounts[account].isTaxExempt = isTaxExempt; return true;
    }

    /** NOTE: This function is not unitarily bidirectional. Including an account changes the existing reflections for all accounts,
        whereas excluding an account merely prevents an account from receiving future rewards, keeping other balances the same.
        TRUE: includeInReward, FALSE: excludeFromReward
    */
    function setRewardStatus(address account, bool include) public virtual onlyOwner returns (bool success) { unchecked {
        require( include == Accounts[account].isExcluded, "Account is already included / excluded.");
        if (include) { 
            if (account == NULL || account == BURN || account == owner) { revert("Can not re-include address"); } // devtithe
            uint len = rExcluded.length; 
            for (uint i; i < len;) {
                if (rExcluded[i] == account) {
                    rExcluded[i] = rExcluded[len - 1]; 
                    rExcluded.pop();
                    Accounts[account].tOwned = 0; 
                    return !(Accounts[account].isExcluded = false);
                } ++i;
            }
        } else { // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
            if (Accounts[account].rOwned > 0) {
                Accounts[account].tOwned = tokenFromReflection(Accounts[account].rOwned);
            }
            rExcluded.push(account); 
            return (Accounts[account].isExcluded = true);
        }
    }}

    function reflectionFromToken(uint tAmount, bool deductTransferFee) public view virtual returns (uint rOwned) {
        if (tAmount > _tTotal) { revert InvalidBalance(); }
        TransferValues memory Values = _getValues(tAmount, !deductTransferFee, NULL, NULL);
        return (deductTransferFee) ? Values.rTransferAmount : Values.rAmount;
    }

    function tokenFromReflection(uint rAmount) public view virtual returns (uint tOwned) {
        if (rAmount > _rTotal) { revert InvalidBalance(); } 
        return rAmount / _getRate();
    }

    function _getRate() public view virtual returns (uint) {
        (uint rSupply, uint tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    /// Gas cost can be further improved by converting this to assembly.
    function _getCurrentSupply() public view virtual returns (uint rSupply, uint tSupply) { unchecked {

        (rSupply, tSupply) = (_rTotal, _tTotal);

        uint len = rExcluded.length; uint rOwned; uint tOwned; address e; 
        for (uint i; i<len;) { 
            e = rExcluded[i];
            (rOwned, tOwned) = (Accounts[e].rOwned, Accounts[e].tOwned);
            if ((rOwned > rSupply) || (tOwned > tSupply)) { 
                return (_rTotal, _tTotal);
            }
            rSupply -= rOwned;
            tSupply -= tOwned;
            ++i;
        }
        return (rSupply < (_rTotal / _tTotal)) ? (_rTotal, _tTotal) : (rSupply, tSupply);
    }}


    function _burn(address from, uint tAmount) public virtual returns (bool) {
        _transfer(from, BURN, tAmount, true); // transfer to BURN, tax exempt. 
        //totalFees += tAmount;
        return true;      
    }

    function _transfer(address from, address to, uint tAmount, bool isTaxExempt) internal virtual override returns (bool) {
        _beforeTokenTransfer(from, to, tAmount);

        if (!isTaxExempt && (Accounts[from].isTaxExempt || Accounts[to].isTaxExempt)) {
            isTaxExempt = true;
        }

        if (to == BURN) { isTaxExempt = true; }

        _transferAllCases(from, to, tAmount, isTaxExempt);

        _afterTokenTransfer(from, to, tAmount);
        return true;
    }

    function _transferExempt(address from, address to, uint tAmount) internal virtual {
        _transfer(from, to, tAmount, true);
    } 

    // Comment out in production code
    function TEST_TRANSFER(address from, address to, uint tAmount, bool forceFeeExemption) public onlyOwner {
        _transfer(from, to, tAmount, forceFeeExemption);
    }


    // 732 gas cost over original, but much more readable.
    function _getValues(uint tAmount, bool isTaxExempt, address from, address to) public view virtual returns (TransferValues memory) {
        
        uint currentRate = _getRate();

        (uint tFeeTotal, uint tFee, uint tLiquidity, uint tBurn) = isTaxExempt ? (0,0,0,0) : _getTFees(tAmount, from, to);
    
        /// NOTE: R values are always T Values * currentRate.
        return TransferValues({
            tTransferAmount: tAmount - tFeeTotal, // tAmount: tAmount,
            tFee: tFee,
            tBurn: tBurn,
            tLiquidity: tLiquidity,

            rAmount: (tAmount * currentRate),
            rTransferAmount: ((tAmount - tFeeTotal) * currentRate),
            rFee: (tFee * currentRate),
            rBurn: (tBurn * currentRate) // rLiquidity: (tLiquidity * currentRate)
        });        
    }

    function _getTFees(uint tAmount, address from, address to) internal view returns (uint tFeeTotal, uint tFee, uint tLiquidity, uint tBurn) {

        Fees memory Fee = /*(useDefaultFees) ? defaultFees :*/ _getTaxValues(from, to); 

        tFee =       tAmount.mulDiv( Fee.ReflectionTax.N, Fee.ReflectionTax.D );
        tLiquidity = tAmount.mulDiv( Fee.LiquidityTax.N, Fee.LiquidityTax.D );
        tBurn =      tAmount.mulDiv( Fee.BurnTax.N, Fee.BurnTax.D );

        tFeeTotal = (tFee + tLiquidity + tBurn); // assert(tFeeTotal <= tAmount);

        return (tFeeTotal, tFee, tLiquidity, tBurn);
    }

    function _transferAllCases(address sender, address recipient, uint tAmount, bool forceFeeExemption) internal virtual {

        TransferValues memory Data = _getValues(tAmount, forceFeeExemption, sender, recipient); // uint currentRate = _getRate();

        Accounts[sender].rOwned -= Data.rAmount; // -= (tAmount * currentRate);   /// Will auto revert if insufficient
        Accounts[recipient].rOwned += Data.rTransferAmount;  /// NOTE: Requires Solidity 0.8+. Do NOT enclose in unchecked bloc

        if (Accounts[sender].isExcluded) { 
            Accounts[sender].tOwned -= tAmount;
        }
        if (Accounts[recipient].isExcluded) { 
            Accounts[recipient].tOwned += Data.tTransferAmount;
        }   
        // save gas by only calling the functions on non-exempt transfers. (x += 0) still costs gas.
        if (!forceFeeExemption) {
            // _takeLiquidity(tLiquidity);
            _reflectFee(Data.rFee, Data.tFee);
            _burnFee(Data.rBurn, Data.tBurn);  // be certain to burn only AFTER reflections / liquidity
        }
        emit Transfer(sender, recipient, Data.tTransferAmount);
    }

    // (uint currentRate, uint tTransferAmount, uint tFee, uint tLiquidity, uint tBurn) = _getValuesAlt(tAmount, isTaxExempt, sender, recipient);
    function _reflectFee(uint rFee, uint tFee) internal { 
        _rTotal -= rFee; 
        // totalFees += tFee;
    }

    function _burnFee(uint rBurnAmount, uint tBurnAmount) internal { 

        Accounts[BURN].rOwned += rBurnAmount;

        if (Accounts[BURN].isExcluded) { 
            Accounts[BURN].tOwned += tBurnAmount;
        }
        /// NOTE: If you're certain to set BURN to ALWAYS excluded, uncomment the next line and comment out the line after that.
        // _tOwned[BURN] += tBurnAmount;
        // emit Burn(tBurnAmount);

    }

    function _getTaxValues(address from, address to) internal view returns (Fees memory) {

        if (useDefaultFees) {
            return defaultFees;
        } else {
            // return Fees( Ratio(0, 100), Ratio(0, 100), Ratio(0, 100) );
        }
    }

}
