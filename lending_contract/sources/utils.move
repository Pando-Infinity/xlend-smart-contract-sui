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
}