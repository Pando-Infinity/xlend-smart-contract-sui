module lending_contract_v2::price_feed {
    use sui::{
        coin::CoinMetadata,
        clock::Clock,
    };
    use pyth::{
        price_info::PriceInfoObject,
        i64::I64,
        pyth::{get_price_no_older_than},
        price::Price,
    };
    use lending_contract_v2::{
        configuration::Configuration,
        utils,
    };

    use fun i64_to_u64 as I64.to_u64;
    use fun is_negative as I64.is_negative;
    use fun lending_contract_v2::utils::vector_to_hex_char as vector.to_hex_char;
    use fun std::string::from_ascii as std::ascii::String.to_string;
    use fun pyth::price_info::get_price_info_from_price_info_object as PriceInfoObject.to_price_info;

    public fun get_value_by_usd<T>(
        price_info_object: &PriceInfoObject,
        max_decimals: u64,
        amount: u64,
        coin_metadata: &CoinMetadata<T>,
        time_threshold: u64,
        clock: &Clock,
    ) : u128 {
        let coin_decimals_u8 = coin_metadata.get_decimals<T>();
        // Standardized amount to max decimals
        let amount_by_max_decimals = (amount as u128) * (utils::power(10, max_decimals) as u128) / (utils::power(10, (coin_decimals_u8 as u64)) as u128);

        let price: Price = get_price_no_older_than(price_info_object, clock, time_threshold);
        let price_u64 = price.get_price().to_u64();
        let exponent_u64 = price.get_expo().to_u64();
        let exponent_power = (utils::power(10, exponent_u64) as u128);
        let value_usd: u128;

        if (price.get_expo().is_negative()) {
            value_usd = (price_u64 as u128) * amount_by_max_decimals / exponent_power;
        } else {
            value_usd = (price_u64 as u128) * amount_by_max_decimals * exponent_power;
        };

        value_usd
    }

    public fun is_valid_price_info_object<T>(
        price_info_object: &PriceInfoObject, 
        configuration: &Configuration,
        coin_metadata: &CoinMetadata<T>,
    ): bool {
        let coin_symbol = coin_metadata.get_symbol().to_string();
        if (!configuration.contains_price_feed_id(coin_symbol)) {
            return false
        };

        let price_info = price_info_object.to_price_info();
        let price_id = price_info.get_price_identifier().get_bytes();
        let price_feed_id = price_id.to_hex_char();

        price_feed_id == configuration.price_feed_id(coin_symbol)
    }

    public fun i64_to_u64(
        price: &I64,
    ): u64 {
        let price_value: u64;
        let is_negative = price.get_is_negative();
        if (!is_negative) {
            price_value = price.get_magnitude_if_positive();
        } else {
            price_value = price.get_magnitude_if_negative();
        };
        price_value
    }

    public fun is_negative (
        price: &I64,
    ): bool {
       price.get_is_negative()
    }
}