module lending_contract_v2::price_feed {
    use sui::{
        coin::CoinMetadata,
        clock::Clock,
    };
    use lending_contract_v2::{
        price_info::PriceInfoObject,
        configuration::Configuration,
        utils,
    };

    use fun lending_contract_v2::utils::vector_to_hex_char as vector.to_hex_char;
    use fun std::string::from_ascii as std::ascii::String.to_string;

    public fun get_value_by_usd<T>(
        price_info: &PriceInfoObject<T>,
        max_decimals: u64,
        amount: u64,
        coin_metadata: &CoinMetadata<T>,
        time_threshold: u64,
        clock: &Clock,
    ): u128 {
        let coin_decimal = coin_metadata.get_decimals<T>();
        let amount_by_max_decimals = (amount as u128) * (utils::power(10, max_decimals) as u128) / (utils::power(10, (coin_decimal as u64)) as u128);
        let (price_u64, expo_u64, is_negative) = price_info.get_price<T>();
        let exponent_power = (utils::power(10, expo_u64) as u128);
        let value_usd: u128;
        if (is_negative) {
            value_usd = (price_u64 as u128) * amount_by_max_decimals / exponent_power; 
        } else {
            value_usd = (price_u64 as u128) * amount_by_max_decimals * exponent_power;
        };

        value_usd
    }

    public fun is_valid_price_info_object<T>(
        price_info_object: &PriceInfoObject<T>, 
        configuration: &Configuration,
        coin_metadata: &CoinMetadata<T>,
    ): bool {
        // let coin_symbol = coin_metadata.get_symbol().to_string();
        // if (!configuration.contains_price_feed_id(coin_symbol)) {
        //     return false
        // };

        // let price_info = price_info_object.to_price_info();
        // let price_id = price_info.get_price_identifier().get_bytes();
        // let price_feed_id = price_id.to_hex_char();

        // price_feed_id == configuration.price_feed_id(coin_symbol)
        true
    }
}