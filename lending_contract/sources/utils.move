module lending_contract::utils {
    use std::vector;
    use pyth::i64::{Self, I64};

    friend lending_contract::offer;
    friend lending_contract::loan;
    friend lending_contract::price_feed;

    public fun u64_to_bytes(num: u64): vector<u8> {
        let vec: vector<u8> = vector[];
        let i = num;
        loop {
            let mod: u8 = (i % 256 as u8);
            vector::push_back(&mut vec, mod);
            i = (i - (mod as u64)) / 256;

            if (i == 0) {
                break
            }
        };
        vec
    }

    public fun u64_to_string(num: u64): vector<u8> {
        let result = vector::empty<u8>();
        let temp = num;
        let zero_ascii = 48; // ASCII value for '0'

        // Handle the case when the number is zero
        if (temp == 0) {
            vector::push_back(&mut result, zero_ascii);
            return result;
        };

        // Extract digits from the number and convert to ASCII
        while (temp > 0) {
            let digit = ((temp % 10) as u8);
            vector::push_back(&mut result, zero_ascii + digit);
            temp = temp / 10;
        };

        // The digits are in reverse order, so we need to reverse the vector
        let reversed_result = vector::empty<u8>();
        let len = vector::length(&result);
        let i = 0;
        while (i < len) {
            vector::push_back(&mut reversed_result, *vector::borrow(&result, len - i - 1));
            i = i + 1;
        };

        reversed_result
    }

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
}