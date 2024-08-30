module lending_contract_v2::price_info {
    public struct PriceInfoObject<phantom T> has key, store {
        id: UID,
        price: u64,
        expo: u64,
        is_negative: bool,
    }
    
    public(package) fun new<T>(
        price: u64,
        expo: u64,
        is_negative: bool,
        ctx: &mut TxContext
    ) {
        let price_info = PriceInfoObject<T> {
            id: object::new(ctx),
            price,
            expo,
            is_negative,
        };
        transfer::public_share_object(price_info);
    }

    public(package) fun update_price_info<T>(
        price_info: &mut PriceInfoObject<T>,
        price: u64,
        expo: u64,
        is_negative: bool,
    ) {
        price_info.price = price;
        price_info.expo = expo;
        price_info.is_negative = is_negative;
    }

    public fun get_price<T>(
        price_info: &PriceInfoObject<T>,
    ): (u64, u64, bool) {
        (price_info.price, price_info.expo, price_info.is_negative)
    }
}