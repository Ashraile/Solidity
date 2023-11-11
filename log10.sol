/** SPDX-License-Identifier: MIT 
    @title Log10Variants
    @custom:improv Ashraile
*/
pragma solidity ^0.8.21;

contract Log10Variants {

    function _log10(uint value) public pure returns (uint result) {  unchecked  {
        if (value >= 10 ** 64) { value /= 10 ** 64; result += 64; }
        if (value >= 10 ** 32) { value /= 10 ** 32; result += 32; }
        if (value >= 10 ** 16) { value /= 10 ** 16; result += 16; }
        if (value >= 10 ** 8)  { value /= 10 ** 8;  result += 8;  }
        if (value >= 10 ** 4)  { value /= 10 ** 4;  result += 4;  }
        if (value >= 10 ** 2)  { value /= 10 ** 2;  result += 2;  }
        if (value >= 10)       { result += 1; }
    }}

    function _log10_v2(uint value) public pure returns (uint result) {  unchecked  {
        for (uint i = 64; i > 0; i /= 2) {
            if (value >= 10 ** i) { value /= 10 ** i; result += i; }
        }
    }}

    function _log10assembly(uint value) public pure returns (uint result) {  assembly  {
        for { let i := 64 } gt(i, 0) { i := div(i, 2) } {
            if gt(value, sub(exp(10, i), 1)) { 
                value := div(value, exp(10, i)) result := add(result, i)
            }
        }
    }}

    function _log10assembly2(uint v) public pure returns (uint r) {  assembly  {
        if gt(v, sub(exp(10,64), 1)) { v := div(v, exp(10, 64)) r := add(r, 64) }
        if gt(v, sub(exp(10,32), 1)) { v := div(v, exp(10, 32)) r := add(r, 32) }
        if gt(v, sub(exp(10,16), 1)) { v := div(v, exp(10, 16)) r := add(r, 16) }
        if gt(v, sub(exp(10,8), 1))  { v := div(v, exp(10, 8))  r := add(r, 8) }
        if gt(v, sub(exp(10,4), 1))  { v := div(v, exp(10, 4))  r := add(r, 4) }
        if gt(v, sub(exp(10,2), 1))  { v := div(v, exp(10, 2))  r := add(r, 2) }
        if gt(v, sub(exp(10,1), 1))  { r := add(r, 1) }
    }}
}
