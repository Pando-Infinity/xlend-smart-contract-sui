module lending_contract::utils {
    use std::vector;

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
}