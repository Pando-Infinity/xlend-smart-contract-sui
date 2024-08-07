module lending_contract_v2::asset_tier {
    use sui::event;
    use std::string::String;

    public struct NewAssetTierEvent has copy, drop {
        id: ID,
        name: String,
        amount: u64,
        duration: u64,
    }

    public struct AssetTierKey<phantom T> has copy, drop, store {
        name: String
    }

    public struct AssetTier<phantom T> has key, store {
        id: UID,
        amount: u64,
        duration: u64,
    }

    public(package) fun new<T>(
        name: String,
        amount: u64,
        duration: u64,
        ctx: &mut TxContext,
    ): AssetTier<T> {
        let asset_tier = AssetTier<T> {
            id: object::new(ctx),
            amount,
            duration,
        };

        event::emit(NewAssetTierEvent {
            id: object::id(&asset_tier),
            name,
            amount,
            duration,
        });

        asset_tier
    }

    public(package) fun update<T>(
        asset_tier: &mut AssetTier<T>,
        amount: u64,
        duration: u64,
    ) {
        asset_tier.amount = amount;
        asset_tier.duration = duration;
    }

    public fun new_asset_tier_key<T>(
        name: String
    ): AssetTierKey<T> {
        AssetTierKey<T> {
            name,
        }
    }

    public fun id<T>(
        asset_tier: &AssetTier<T>
    ): ID {
        object::id(asset_tier)
    }    

    public fun amount<T>(
        asset_tier: &AssetTier<T>
    ): u64 {
        asset_tier.amount
    }

    public fun duration<T>(
        asset_tier: &AssetTier<T>
    ): u64 {
        asset_tier.duration
    }
}