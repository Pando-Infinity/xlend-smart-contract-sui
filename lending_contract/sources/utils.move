module lending_contract::utils {
    use pyth::i64::{Self, I64};

    friend lending_contract::offer;
    friend lending_contract::loan;
    friend lending_contract::price_feed;

    public(friend) fun power(base: u64, exponent: u64): u128 {
        let result = 1;
        let i = 1;
            
        while (i <= exponent) {
            result = result * base;
            i = i + 1;
        };
        
        (result as u128)
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