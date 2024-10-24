module enso_lending::operator_offer {
	use std::string::String;
    use sui::coin::{Coin, CoinMetadata};
    use sui::balance::Balance;
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
        asset::Asset,
        operator::OperatorCap,
        utils::{Self, default_rate_factor, seconds_in_year},
    };

    public entry fun system_cancel_offer<T>(
        _: &OperatorCap,
        version: &Version,
        state: &mut State,
        offer_id: ID,
        lend_coin: Coin<T>,
        waiting_interest: Coin<T>,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let offer_key = offer_registry::new_offer_key<T>(offer_id);
        assert!(state.contain<OfferKey<T>, Offer<T>>(offer_key), ENotFoundOfferToCancel);
        let offer = state.borrow_mut<OfferKey<T>, Offer<T>>(offer_key);
        offer.system_cancel_offer(
            lend_coin,
            waiting_interest,
            ctx,
        );
    }
}