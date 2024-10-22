module lending_contract::utils {
    use std::vector::{Self};
    use std::string::{Self, String};
    use pyth::i64::{Self, I64};

    friend lending_contract::offer;
    friend lending_contract::loan;
    friend lending_contract::price_feed;

    const HEXTABLE : vector<vector<u8>> = vector[b"0", b"1", b"2", b"3", b"4", b"5", b"6", b"7", b"8", b"9", b"a", b"b", b"c", b"d", b"e", b"f"];

    public(friend) fun power(base: u64, exponent: u64): u64 {
        let result = 1;
        let i = 1;
            
        while (i <= exponent) {
            result = result * base;
            i = i + 1;
        };
        
        result
    }

    public (friend) fun i64_to_u64(
        price: &I64,
    ): u64 {
        let price_value: u64;
        let is_negative = i64::get_is_negative(price);
        if (!is_negative) {
            price_value = i64::get_magnitude_if_positive(price);
        } else {
            price_value = i64::get_magnitude_if_negative(price);
        };
        price_value
    }

    public (friend) fun is_negative (
        price: &I64,
    ): bool {
        let is_negative = i64::get_is_negative(price);
       
        is_negative
    }

    public (friend) fun vector_to_hex_char (
        decimal: vector<u8>,
    ): String {
        let i = 0;
        let hex_string = string::utf8(b"0x");
        while (i < vector::length<u8>(&decimal)) {
            let element = vector::borrow<u8>(&decimal, i);
            let quotient = *element / 16;
            let rest = *element % 16;
            let quotient_to_hex = decimal_to_hex_char(quotient);
            let rest_to_hex = decimal_to_hex_char(rest);

            string::append(&mut hex_string, quotient_to_hex);
            string::append(&mut hex_string, rest_to_hex);
            
            i = i + 1;
        };

        hex_string
    }

    public fun decimal_to_hex_char (
        element: u8,
    ): String {
        let value = vector::borrow<vector<u8>>(&HEXTABLE, (element as u64));
            
        string::utf8(*value)
    }
}