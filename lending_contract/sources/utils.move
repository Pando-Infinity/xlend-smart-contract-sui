module enso_lending::utils {
    use std::{
        type_name,
        string::{Self, String}
    };

    use fun std::string::utf8 as vector.to_string;

    const HEXTABLE : vector<vector<u8>> = vector[b"0", b"1", b"2", b"3", b"4", b"5", b"6", b"7", b"8", b"9", b"a", b"b", b"c", b"d", b"e", b"f"];
    const DEFAULT_RATE_FACTOR: u64 = 10000;
    const SECOND_IN_YEAR: u64 = 31536000;

    public fun power(base: u64, exponent: u64): u64 {
        let mut result = 1;
        let mut i = 1;
            
        while (i <= exponent) {
            result = result * base;
            i = i + 1;
        };
        
        result
    }

    public fun vector_to_hex_char (
        decimal: vector<u8>,
    ): String {
        let mut i = 0;
        let mut hex_string = string::utf8(b"0x");
        while (i < vector::length<u8>(&decimal)) {
            let element = vector::borrow<u8>(&decimal, i);
            let quotient = *element / 16;
            let rest = *element % 16;
            let quotient_to_hex = decimal_to_hex_char(quotient);
            let rest_to_hex = decimal_to_hex_char(rest);

            hex_string.append(quotient_to_hex);
            hex_string.append(rest_to_hex);
            
            i = i + 1;
        };

        hex_string
    }

    #[allow(implicit_const_copy)]
    public fun decimal_to_hex_char(
        element: u8,
    ): String {
        let value = *vector::borrow<vector<u8>>(&HEXTABLE, (element as u64));
            
        value.to_string()
    }

    public fun get_type<T>(): String {
        let type_name = type_name::get<T>();
        string::from_ascii(type_name.into_string())
    }

    public fun default_rate_factor(): u64 {
        DEFAULT_RATE_FACTOR
    }

    public fun seconds_in_year(): u64 {
        SECOND_IN_YEAR
    }
}
