// decimal_conversion.rs

use crate::symbolic_number::SymbolicNumber;

/// Convert a decimal string into a SymbolicNumber (base-256 digits)
pub fn string_to_symbolic_number(s: &str) -> SymbolicNumber {
    let mut digits: Vec<u8> = Vec::new();
    // parse input string into Vec<u8> decimal digits
    let mut decimal_digits: Vec<u8> = s
        .chars()
        .filter(|c| c.is_ascii_digit())
        .map(|c| c.to_digit(10).unwrap() as u8)
        .collect();

    if decimal_digits.is_empty() {
        return SymbolicNumber { digits: vec![0] };
    }

    // repeatedly divide by 256, collecting remainders as base-256 digits
    while !decimal_digits.is_empty() {
        let mut remainder = 0u16;
        let mut new_decimal: Vec<u8> = Vec::new();

        for &d in &decimal_digits {
            let num = remainder * 10 + d as u16;
            let q = num / 256;
            remainder = num % 256;
            if !new_decimal.is_empty() || q != 0 {
                new_decimal.push(q as u8);
            }
        }

        digits.push(remainder as u8);
        decimal_digits = new_decimal;
    }

    SymbolicNumber { digits } // least-significant digit first
}

/// Convert a SymbolicNumber (base-256 digits) back into decimal string
pub fn symbolic_number_to_string(n: &SymbolicNumber) -> String {
    if n.digits.is_empty() {
        return "0".to_string();
    }

    // copy digits (least-significant first)
    let mut digits: Vec<u16> = n.digits.iter().map(|&x| x as u16).collect();
    let mut result = Vec::new();

    while !digits.is_empty() {
        let mut remainder = 0u16;
        let mut new_digits = Vec::new();

        for &d in &digits {
            let num = remainder * 256 + d;
            let q = num / 10;
            remainder = num % 10;
            if !new_digits.is_empty() || q != 0 {
                new_digits.push(q);
            }
        }

        result.push(remainder as u8);
        digits = new_digits;
    }

    // reverse to get most-significant digit first
    result.reverse();
    String::from_utf8(result.iter().map(|d| d + b'0').collect()).unwrap()
}

