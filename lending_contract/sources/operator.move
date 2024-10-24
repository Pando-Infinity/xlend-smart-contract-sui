module enso_lending::operator {
    use std::string::String;
    use sui::coin::{Coin, CoinMetadata};
    use sui::clock::Clock;

    use pyth::price_info::PriceInfoObject;    
    use enso_lending::{
        version::{Version},
        configuration::{Self, Configuration},
        custodian::Custodian,
        state::{Self, State},
        custodian,
        asset_tier::{Self, AssetTierKey, AssetTier},
        offer_registry::{Self, OfferKey, Offer},
        loan_registry::{Self, Loan, LoanKey},
        utils,
    };
    use fun enso_lending::price_feed::is_valid_price_info_object as PriceInfoObject.is_valid;

    const ENotFoundOfferToCancel: u64 = 1;

    public struct OperatorCap has key, store {
        id: UID
    }

    fun init(ctx: &mut TxContext) {
        let operator_cap = OperatorCap {
            id: object::new(ctx),
        };

        transfer::transfer(operator_cap, @operator);
    }

    public entry fun init_system<T>(
        _: &OperatorCap,
        version: &Version,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        max_offer_interest: u64,
        min_health_ratio: u64, 
        hot_wallet: address,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();
        configuration::new(
            lender_fee_percent,
            borrower_fee_percent,
            max_offer_interest,
            min_health_ratio,
            hot_wallet,
            ctx,
        );
        state::new(ctx);
        custodian::new<T>(ctx);
    }
 
    public entry fun update_configuration(
        _: &OperatorCap,
        version: &Version,
        configuration: &mut Configuration,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        max_offer_interest: u64,
        min_health_ratio: u64, 
        hot_wallet: address,
    ) {
        version.assert_current_version();
        configuration.update(
            lender_fee_percent,
            borrower_fee_percent,
            max_offer_interest,
            min_health_ratio,
            hot_wallet,
        );
    }

    public entry fun init_asset_tier<T>(
        _: &OperatorCap,
        version: &Version,
        state: &mut State,
        name: String,
        amount: u64,
        duration: u64,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let lend_token = utils::get_type<T>();
        let asset_tier = asset_tier::new<T>(
            name,
            amount,
            duration,
            lend_token,
            ctx,
        );
        let asset_tier_key = asset_tier::new_asset_tier_key<T>(name);
        state.add<AssetTierKey<T>, AssetTier<T>>(asset_tier_key, asset_tier);
    }

    public entry fun update_asset_tier<T>(
        _: &OperatorCap,
        version: &Version,
        state: &mut State,
        name: String,
        amount: u64,
        duration: u64,
    ) {
        version.assert_current_version();

        let asset_tier_key = asset_tier::new_asset_tier_key<T>(name);
        let asset_tier = state.borrow_mut<AssetTierKey<T>, AssetTier<T>>(asset_tier_key);

        asset_tier.update<T>(
            amount,
            duration,
        );
    }

    public entry fun delete_asset_tier<T>(
        _: &OperatorCap,
        version: &Version,
        state: &mut State,
        name: String,
    ) {
        version.assert_current_version();

        let asset_tier_key = asset_tier::new_asset_tier_key<T>(name);
        let asset_tier = state.remove<AssetTierKey<T>, AssetTier<T>>(asset_tier_key);

        asset_tier.delete();
    }

    public(package) fun new_operator(
        user_address: address,
        ctx: &mut TxContext,
    ) {
        let operator_cap = OperatorCap {
            id: object::new(ctx),
        };
        transfer::transfer(operator_cap, user_address);
    }
}