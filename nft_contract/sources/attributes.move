module nft_contract::attributes {
    use std::{
        ascii::{Self, String}
    };
    use sui::vec_map::{Self, VecMap};

    const EMismatchedKeyValueLength: u64 = 1;

    public struct Attributes has store, copy, drop {
        map: VecMap<String, String>,
    }

    public fun new_from_vec(
        mut attribute_keys: vector<ascii::String>,
        mut attribute_values: vector<ascii::String>,
    ): Attributes {
        assert!(
            vector::length(&attribute_keys) == vector::length(&attribute_values),
            EMismatchedKeyValueLength,
        );

        let mut i = 0;
        let n = vector::length(&attribute_keys);
        let mut map = vec_map::empty<ascii::String, ascii::String>();

        while (i < n) {
            let attribute_key = vector::pop_back(&mut attribute_keys);
            let attribute_value = vector::pop_back(&mut attribute_values);

            vec_map::insert(
                &mut map,
                attribute_key,
                attribute_value,
            );

            i = i + 1;
        };

        Attributes { map }
    }
}