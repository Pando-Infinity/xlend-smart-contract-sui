module lending_contract_v2::offer {
    use sui::coin::Coin;
    use std::string::String;
    use lending_contract_v2::{
        version::Version,
        configuration::Configuration,
        state::State,
        asset_tier::{Self, AssetTier, AssetTierKey},
        offer_registry::{Self, OfferKey, Offer},
    };

    const EInvalidInterestValue: u64 = 1;
    const ENotFoundAssetTier: u64 = 2;
    const ENotEnoughBalanceToCreateOffer: u64 = 3;
    const ENotFoundOfferToCancel: u64 = 4;
    const ENotFoundOfferToEdit: u64 = 5;

    public entry fun create_offer<T>(
        version: &Version,
        state: &mut State,
        configuration: &Configuration,
        asset_tier_name: String,
        lend_coin: Coin<T>,
        interest: u64,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();
        let lender = ctx.sender();
        
        assert!(interest > 0, EInvalidInterestValue);

        let asset_tier_key = asset_tier::new_asset_tier_key<T>(asset_tier_name);
        assert!(state.contain<AssetTierKey<T>, AssetTier<T>>(asset_tier_key), ENotFoundAssetTier);
        let asset_tier = state.borrow<AssetTierKey<T>, AssetTier<T>>(asset_tier_key);

        assert!(lend_coin.value() == asset_tier.amount(), ENotEnoughBalanceToCreateOffer);

        let hot_wallet = configuration.hot_wallet();
        transfer::public_transfer(lend_coin, hot_wallet);

        let offer = offer_registry::new_offer<T>(asset_tier.id(), asset_tier_name, asset_tier.amount(), asset_tier.duration(), interest, lender, ctx);
        let offer_id = object::id(&offer);
        let offer_key = offer_registry::new_offer_key<T>(offer_id);

        state.add<OfferKey<T>, Offer<T>>(offer_key, offer);
        state.add_offer(offer_id, lender, ctx);
    }

    public entry fun request_cancel_offer<T>(
        version: &Version,
        state: &mut State,
        offer_id: ID,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();
        let sender = ctx.sender();
        let offer_key = offer_registry::new_offer_key<T>(offer_id);
        assert!(state.contain<OfferKey<T>, Offer<T>>(offer_key), ENotFoundOfferToCancel);
        let offer = state.borrow_mut<OfferKey<T>, Offer<T>>(offer_key);

        offer.cancel_offer(sender);
    }

    public entry fun edit_offer<T>(
        version: &Version,
        state: &mut State,
        offer_id: ID,
        interest: u64,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();
        let sender = ctx.sender();
        let offer_key = offer_registry::new_offer_key<T>(offer_id);
        assert!(state.contain<OfferKey<T>, Offer<T>>(offer_key), ENotFoundOfferToEdit);
        let offer = state.borrow_mut<OfferKey<T>, Offer<T>>(offer_key);
        
        offer.edit_offer(interest, sender);
    }
}