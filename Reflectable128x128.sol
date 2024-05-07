/// SPDX-LICENSE-IDENTIFIER: MIT (just star & link github <3)
/// @title Reflectable128x128.sol

pragma solidity 0.8.25;

address constant NULL = address(0);
address constant BURN = address(57005);

uint256 constant MAX256 = ~uint256(0);
uint128 constant MAX128 = ~uint128(0);

/** 
 *  @dev Contract module that enables a token reflection system. Compatible with standard ERC20 / BEP20 implementations.
 *  Uses packed 128 bit values instead of 256 bit values, cutting transfer costs by 30%.
 *  @custom:origin Safemoon.sol (https://github.com/safemoonprotocol/Safemoon.sol/blob/main/Safemoon.sol)
 *  @custom:improv Jasper Wolf (https://www.github.com/Ashraile)
 *  @custom:metadata [@license MIT, @version 3.4, @minpragma 0.8.21]
 *  NOTE: Optimal values: decimal of <=12 and supply <= 1 quadrillion (lower decimals and token amounts = higher precision).
 *  Currently only supports static or deflationary tokens, i.e. tokens with a starting supply that stays constant or decreases.
 *  MAX128: 340282366920938463463374607431768211455
 */

abstract contract Reflectable128x128 is BEP20 { // inherits: Ownable.sol, Context.sol, BEP20.sol

    error INVALID_STATUS(address account, bool rewardStatus);

    constructor() {
        uint256 supply = super.totalSupply(); // Need the previous total supply before overriding `totalSupply()` because _rTotal at this point is 0.

        require(supply <= MAX128, "overflow");
        require((MAX128 / uint128(supply)) >= 1e12, "insufficient precision");

        _tTotal = uint128(supply);
        _rTotal = (MAX128 - (MAX128 % _tTotal)); 

        _balances[owner].rOwned = _rTotal; // set total supply to owner
    }

    mapping (address => Account) internal _balances;

    /// NOTE: Packing the reflection balances within `uint128` keeps `rOwned` and `tOwned` within one `uint256` sload(), cutting gas costs by 30%
    struct Account { 
        uint128 rOwned; // 16 bytes
        uint128 tOwned; // 16 bytes
        bool isFeeExempt;
        bool isExcluded;  
    }

    address[] internal _rExcluded;

    uint128 internal immutable _tTotal;
    uint128 internal _rTotal; 

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function balanceOf(address account) public view virtual override returns (uint256) { // autocast from uint128
        return _balances[account].isExcluded ? _balances[account].tOwned : tokenFromReflection(_balances[account].rOwned); 
    }

    function totalSupply() public view virtual override returns (uint) {  unchecked  {
        return releaseSupply /* + mintedTokens */ - balanceOf(BURN);
    }}

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function reflectToHolders(uint128 tAmount, uint128 rate) internal virtual {  unchecked  {
        _rTotal -= (tAmount * rate);
    }}

    // Gets tokens owned from a reflection balance.
    function tokenFromReflection(uint128 rAmount) internal view virtual returns (uint128 /* tOwned */) {  unchecked  {
        return (rAmount / getRate());
    }}

    // Gets reflected representation of a token balance.
    function reflectionFromToken(uint128 tAmount) internal view virtual returns (uint128 /* rOwned */) {  unchecked  {
        return (tAmount * getRate());
    }}

    function getRate() internal view virtual returns (uint128 /* currentRate */) {  unchecked  { // unchecked division by 0 still reverts
        (uint128 rSupply, uint128 tSupply) = getCurrentSupply(); 
        return (rSupply / tSupply); 
    }}

    function getCurrentSupply() internal view virtual returns (uint128 rSupply, uint128 tSupply) {  unchecked  { 

        (rSupply, tSupply) = (_rTotal, _tTotal);

        address[] memory rExcluded = _rExcluded; // copying from memory is cheaper than sload
        uint256 len = rExcluded.length; 
        uint128 rOwnedAcc; uint128 tOwnedAcc; 
        address account;

        for (uint i; i < len; ++i) {
            account = rExcluded[i];
            (rOwnedAcc, tOwnedAcc) = (_balances[account].rOwned, _balances[account].tOwned);
            if (rOwnedAcc > rSupply || tOwnedAcc > tSupply) { return (_rTotal, _tTotal); }
            rSupply -= rOwnedAcc; 
            tSupply -= tOwnedAcc;
        }

        return (rSupply < (_rTotal / _tTotal)) ? (_rTotal, _tTotal) : (rSupply, tSupply);
    }}

    /**
     * @dev Combines Safemoon's `_transferStandard()`, `_transferFromExcluded()`, `_transferToExcluded()`, and `_transferBothExcluded()`.
     * NOTE: Requires Solidity 0.8+. Emits a {Transfer} event.
     * @param from The sender address.
     * @param to The receiver address.
     * @param amount The amount to deduct from sender.
     * @param remainder The amount to send to receiver (after fee deduction).
     * @return rate128 The rate to use for fee transfers before reflecting to holders.
     * NOTE: few safety checks.
     */

    function _transferSupportingFee(
        address from, 
        address to, 
        uint256 amount, 
        uint256 remainder
    ) internal virtual returns (uint128 rate128) {  unchecked  { 

        assert((remainder <= amount) && (amount == uint128(amount))); // remainder <= amount <= type(uint128).max

        (uint128 amount128, uint128 remainder128) = (uint128(amount), uint128(remainder));

        rate128 = getRate(); // NOTE: R values are always T Values * rate (currentRate)

        _balances[from].rOwned -= (amount128 * rate128);
        _balances[to].rOwned += (remainder128 * rate128);

        if (_balances[from].isExcluded) { _balances[from].tOwned -= amount128; }
        if (_balances[to].isExcluded)  { _balances[to].tOwned += remainder128; }

        emit Transfer(from, to, remainder);
    }}

    /*
     * @dev Sends a fee before reflections.
     */
    function sendFeeTo(address account, uint128 tAmount, uint128 rate) internal virtual {
        if (tAmount > 0) {
            // if (tAmount != uint128(tAmount)) { revert cast128(); }
            _balances[account].rOwned += (tAmount * rate);
            if (_balances[account].isExcluded) { 
                _balances[account].tOwned += tAmount;
            }
        }
    }


    ////////////////////////////////////////////// OnlyOwner functions //////////////////////////////////////////////

    // would use calldata but we also call from within contract
    function setFeeExempt(address[] memory accounts, bool exempt) public virtual onlyOwner {  unchecked  {
        uint256 len = accounts.length;
        for (uint i; i < len; ++i) {
            _balances[accounts[i]].isFeeExempt = exempt;
        }
    }}

    /** NOTE: This function is not unitarily bidirectional. Including an account changes the existing reflections for all accounts,
        whereas excluding an account merely prevents an account from receiving future rewards, keeping other balances the same.
        TRUE: includeInReward, FALSE: excludeFromReward 
    */
    function setRewardStatus(address[] memory accounts, bool include) public virtual onlyOwner {  unchecked  {
        uint256 len = accounts.length;
        for (uint i; i < len; ++i) {
            _setRewardStatus(accounts[i], include);
        }
    }}

    function _setRewardStatus(address account, bool include) internal virtual {  unchecked  {
        if (include != _balances[account].isExcluded) { 
            revert INVALID_STATUS(account, include);
        }
        if (include) { 
            uint len = _rExcluded.length; 
            for (uint i; i < len; ++i) {
                if (_rExcluded[i] == account) {
                    _rExcluded[i] = _rExcluded[len - 1]; // swapa with last and pop
                    _rExcluded.pop();
                    _balances[account].tOwned = 0; 
                    _balances[account].isExcluded = false;
                    break;
                }
            }
        } else { 
            // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
            // yes we can
            if (_balances[account].rOwned > 0) { 
                _balances[account].tOwned = tokenFromReflection(_balances[account].rOwned);
            }
            _rExcluded.push(account); 
            _balances[account].isExcluded = true;
        }
    }}

    // uint8 internal immutable _reflectionTax;
    // function excludeFromReward(address account) public virtual onlyOwner { _setRewardStatus(account, false); }
    // function includeInReward(address account) external virtual onlyOwner { _setRewardStatus(account, true); }
    // function setReflectionTaxPercent(uint percent) public virtual onlyOwner { _reflectionTaxPercent = percent; }
    /* 
    function _transfer(address from, address to, uint amount, bool isFeeExempt) internal virtual override {
        uint256 tReflected; // 0
        if (!(isFeeExempt || _isFeeExempt[from] || _isFeeExempt[to])) {
            tReflected = (amount * _reflectionTax) / 100;
        }
        uint128 rate = _transferSupportingFee(from, to, amount, (amount - tReflected));

        /// NOTE: rate is the same until `reflect()` is called, so no recalculation is necessary
        if (tReflected > 0) { 
            reflectToHolders(uint128(tReflected), rate);
        }
    } 
    */
}
