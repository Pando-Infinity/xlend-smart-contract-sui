module enso_lending::configuration {
    use sui::{
        dynamic_field as field,
        table::{Self, Table}
    };
    use std::string::String;
    use enso_lending::utils;

    use fun std::string::utf8 as vector.to_string;

    const EPriceFeedIdAlreadyExisted: u64 = 1;
    const EPriceFeedIdIsNotExisted: u64 = 2;
    const ETokenAlreadyAdded: u64 = 3;

    const LEND_TYPE: vector<u8> = b"Lend";
    const COLLATERAL_TYPE: vector<u8> = b"Collateral";

    public struct Configuration has key, store {
        id: UID,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        max_offer_interest: u64,
        min_health_ratio: u64,
        hot_wallet: address,
        max_price_age_seconds: u64,
        price_feed_ids:  Table<String, String>,
    }

    public(package) fun new(
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        max_offer_interest: u64,
        min_health_ratio: u64,
        hot_wallet: address,
        max_price_age_seconds: u64,
        ctx: &mut TxContext,
    ) {
        let configuration = Configuration {
            id: object::new(ctx),
            lender_fee_percent,
            borrower_fee_percent,
            max_offer_interest,
            min_health_ratio,
            hot_wallet,
            max_price_age_seconds,
            price_feed_ids: table::new<String, String>(ctx),
        };
        transfer::public_share_object(configuration);
    }

    public(package) fun update(
        configuration: &mut Configuration,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        max_offer_interest: u64,
        min_health_ratio: u64,
        hot_wallet: address,
        max_price_age_seconds: u64,
    ) {
        configuration.lender_fee_percent = lender_fee_percent;
        configuration.borrower_fee_percent = borrower_fee_percent;
        configuration.max_offer_interest = max_offer_interest;
        configuration.min_health_ratio = min_health_ratio; 
        configuration.hot_wallet = hot_wallet;
        configuration.max_price_age_seconds = max_price_age_seconds;
    }

    public(package) fun add<K: copy + drop + store, V: store>(
        configuration: &mut Configuration,
        key: K,
        value: V
    ) {
        field::add(&mut configuration.id, key, value);
    }

    public(package) fun borrow<K: copy + drop + store, V: store>(
        configuration: &Configuration,
        key: K
    ): &V {
        field::borrow<K, V>(&configuration.id, key)
    }

    public(package) fun borrow_mut<K: copy + drop + store, V: store>(
        configuration: &mut Configuration,
        key: K
    ): &mut V {
        field::borrow_mut<K, V>(&mut configuration.id, key)
    }

    public(package) fun contain<K: copy + drop + store, V: store>(
        configuration: &Configuration,
        key: K
    ): bool {
        field::exists_with_type<K, V>(&configuration.id, key)
    }

    public(package) fun remove<K: copy + drop + store, V: store>(
        configuration: &mut Configuration,
        key: K
    ): V {
        field::remove<K, V>(&mut configuration.id, key)
    }

    public(package) fun add_token<T>(
        configuration: &mut Configuration,
        coin_symbol: String,
        price_feed_id: String,
        is_lend_token: bool,
    ) {
        let token_type = utils::get_type<T>();
        assert!(!configuration.contain<String, String>(token_type), ETokenAlreadyAdded);
        if (is_lend_token) {
            configuration.add<String, String>(token_type, LEND_TYPE.to_string());
        } else {
            configuration.add<String, String>(token_type, COLLATERAL_TYPE.to_string());
        };
        configuration.add_price_feed_id(coin_symbol, price_feed_id);
    }

    public(package) fun remove_token<T>(
        configuration: &mut Configuration,
        coin_symbol: String,
    ) {
        let token_type = utils::get_type<T>();
        configuration.remove<String, String>(token_type);
        configuration.remove_price_feed_id(coin_symbol);
    }

    public(package) fun add_price_feed_id(
        configuration: &mut Configuration,
        coin_symbol: String,
        price_feed_id: String,
    ) {
        assert!(!configuration.price_feed_ids.contains(coin_symbol), EPriceFeedIdAlreadyExisted);
        configuration.price_feed_ids.add(coin_symbol, price_feed_id);
    }

    public(package) fun update_price_feed_id(
        configuration: &mut Configuration,
        coin_symbol: String,
        price_feed_id: String,
    ) {
        assert!(configuration.price_feed_ids.contains(coin_symbol), EPriceFeedIdIsNotExisted);
        let old_price_feed_id = configuration.price_feed_ids.borrow_mut(coin_symbol);
        *old_price_feed_id = price_feed_id;
    }

    public(package) fun remove_price_feed_id(
        configuration: &mut Configuration,
        coin_symbol: String,
    ) {
        assert!(configuration.price_feed_ids.contains(coin_symbol), EPriceFeedIdIsNotExisted);
        configuration.price_feed_ids.remove(coin_symbol);
    }

    public fun lender_fee_percent(
        configuration: &Configuration
    ): u64 {
        configuration.lender_fee_percent
    }

    public fun borrower_fee_percent(
        configuration: &Configuration
    ): u64 {
        configuration.borrower_fee_percent
    }

    public fun max_offer_interest(
        configuration: &Configuration
    ): u64 {
        configuration.max_offer_interest
    }

    public fun hot_wallet(
        configuration: &Configuration
    ): address {
        configuration.hot_wallet
    }

    public fun min_health_ratio(
        configuration: &Configuration
    ): u64 {
        configuration.min_health_ratio
    }

    public fun max_price_age_seconds (
        configuration: &Configuration
    ): u64 {
        configuration.max_price_age_seconds
    }

    public fun price_feed_id(
        configuration: &Configuration,
        coin_symbol: String,
    ): String {
        assert!(configuration.price_feed_ids.contains(coin_symbol), EPriceFeedIdIsNotExisted);
        *configuration.price_feed_ids.borrow(coin_symbol)
    }

    public fun contains_price_feed_id(
        configuration: &Configuration,
        coin_symbol: String,
    ): bool {
        configuration.price_feed_ids.contains(coin_symbol)
    }

    public fun is_valid_lend_coin<T>(
        configuration: &Configuration
    ): bool {
        let token_type = utils::get_type<T>();
        if (!configuration.contain<String, String>(token_type)) {
            return false
        };

        *configuration.borrow<String, String>(token_type) == LEND_TYPE.to_string()
    }

    public fun is_valid_collateral_coin<T>(
        configuration: &Configuration
    ): bool {
        let token_type = utils::get_type<T>();
        if (!configuration.contain<String, String>(token_type)) {
            return false
        };
        *configuration.borrow<String, String>(token_type) == COLLATERAL_TYPE.to_string()
    }
}