module nft_contract::operator {
    use sui::kiosk;
    use std::{
        string::String,
        ascii,
    };
    use nft_contract::{
        version::Version,
        early_contributor_pass::{Self, EarlyContributorPass},
    };

    public struct OperatorCap has key, store {
        id: UID
    }

    fun init(ctx: &mut TxContext) {
        let operator_cap = OperatorCap {
            id: object::new(ctx),
        };

        transfer::transfer(operator_cap, @operator);
    }

    public entry fun mint_nft_to_address(
        _: &OperatorCap,
        version: &Version,
        name: String,
        symbol: String,
        description: String,
        image_url: vector<u8>,
        attribute_keys: vector<ascii::String>,
        attribute_values: vector<ascii::String>,
        receiver: address,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let nft = early_contributor_pass::mint_nft(
            name,
            symbol,
            description,
            image_url,
            attribute_keys,
            attribute_values,
            receiver,
            ctx,
        );

        transfer::public_transfer(nft, receiver);
    }

    #[allow(lint(share_owned))]
    public entry fun mint_nft_to_kiosk(
        _: &OperatorCap,
        version: &Version,
        name: String,
        symbol: String,
        description: String,
        image_url: vector<u8>,
        attribute_keys: vector<ascii::String>,
        attribute_values: vector<ascii::String>,
        receiver: address,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let (mut kiosk, kiosk_owner_cap) = kiosk::new(ctx);
        let nft = early_contributor_pass::mint_nft(
            name,
            symbol,
            description,
            image_url,
            attribute_keys,
            attribute_values,
            receiver,
            ctx,
        );
        kiosk.place<EarlyContributorPass>(&kiosk_owner_cap, nft);

        transfer::public_transfer(kiosk_owner_cap, receiver);
        transfer::public_share_object(kiosk);
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