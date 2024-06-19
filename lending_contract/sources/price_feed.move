module lending_contract::price_feed {
    use std::debug;

    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::clock::{Self, Clock};

    use pyth::price_info::PriceInfoObject;
    use pyth::state::{State as PythState};
    use pyth::i64::{Self, I64};
    use pyth::pyth::{get_price_no_older_than};
    use pyth::price::{Self, Price};

    use lending_contract::configuration::{Self, Configuration};
    use lending_contract::utils;
    
    friend lending_contract::loan;

    public (friend) fun get_value_by_usd<T>(
        configuration: &Configuration,
        max_decimals: u64,
        amount: u64,
        coinMetadata: &CoinMetadata<T>,
        pyth_state: &PythState,
        price_info_object: &PriceInfoObject,
        clock: &Clock,
    ) : u128 {
        let time_threshold = configuration::price_time_threshold(configuration);
        let coin_decimals_u8 = coin::get_decimals<T>(coinMetadata);
        // Standardized amount to max decimals
        let amount_by_max_decimals = (amount as u128) * (utils::power(10, max_decimals) as u128) / (utils::power(10, (coin_decimals_u8 as u64)) as u128);

        let price: Price = get_price_no_older_than(price_info_object, clock, time_threshold);
        let price_u64 = utils::i64_to_u64(&price::get_price(&price));
        let exponent_u64 = utils::i64_to_u64(&price::get_expo(&price));
        let exponent_power = (utils::power(10, exponent_u64) as u128);
        let value_usd: u128;

        if (utils::is_negative(&price::get_expo(&price))) {
            value_usd = (price_u64 as u128) * amount_by_max_decimals / exponent_power;
        } else {
            value_usd = (price_u64 as u128) * amount_by_max_decimals * exponent_power;
        };

        value_usd
    }
}