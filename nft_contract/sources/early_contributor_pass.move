module nft_contract::early_contributor_pass {
    use sui::{
        url::Url,
        package,
        display,
        transfer_policy,
        event,
        kiosk::{Kiosk, KioskOwnerCap},
    };
    use std::{
        ascii,
        string::String
    };
    use kiosk::royalty_rule::{Self};
    use nft_contract::{
        version::Version,
        attributes::{Self, Attributes},
        collection,
    };

    use fun std::string::utf8 as vector.to_string;
    use fun sui::url::new_unsafe_from_bytes as vector.to_url;

    const BPS: u16 = 400;
    const PROJECT_URL: vector<u8> = b"https://app.ensofi.xyz";

    public struct EARLY_CONTRIBUTOR_PASS has drop {}

    public struct Witness has drop {}

    public struct EarlyContributorPass has key, store {
        id: UID,
        name: String,
        symbol: String,
        description: String,
        image_url: Url,
        attributes: Attributes,
    }

    public struct MintedNftEvent has copy, drop {
        nftId: ID,
        wallet_address: address,
    }

    public struct BurnedNftEvent has copy, drop {
        nftId: ID,
        wallet_address: address,
    }

    #[allow(lint(share_owned))]
    fun init(
        otw: EARLY_CONTRIBUTOR_PASS,
        ctx: &mut TxContext,
    ) {
        let nft_publisher = package::claim(otw, ctx);
        let collection = collection::new(ctx);
        collection::display(&nft_publisher, ctx);

        let keys = vector[
            b"name".to_string(),
            b"symbol".to_string(),
            b"description".to_string(),
            b"url".to_string(),
            b"image_url".to_string(),
            b"project_url".to_string(),
            b"attributes".to_string(),
        ];
        let values = vector[
            b"{name}".to_string(),
            b"{symbol}".to_string(),
            b"{description}".to_string(),
            b"{image_url}".to_string(),
            b"{image_url}".to_string(),
            PROJECT_URL.to_string(),
            b"{attributes}".to_string(),
        ];
        let mut nft_display = display::new_with_fields<EarlyContributorPass>(
            &nft_publisher, keys, values, ctx
        );
        nft_display.update_version();

        let (mut transfer_policy, transfer_policy_cap) = transfer_policy::new<EarlyContributorPass>(&nft_publisher, ctx);
        royalty_rule::add<EarlyContributorPass>(&mut transfer_policy, &transfer_policy_cap, BPS, 0);

        transfer::public_transfer(nft_publisher, @admin);
        transfer::public_transfer(nft_display, @admin);
        transfer::public_transfer(transfer_policy_cap, @admin);
        transfer::public_share_object(transfer_policy);
        transfer::public_share_object(collection);
    }

    public entry fun burn_nft(
        version: &Version,
        nft: EarlyContributorPass,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        burn(nft, ctx);
    }

    public entry fun burn_nft_from_kiosk(
        version: &Version,
        nftId: ID,
        kiosk: &mut Kiosk,
        kiosk_owner_cap: &KioskOwnerCap,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();

        let nft = kiosk.take<EarlyContributorPass>(kiosk_owner_cap, nftId);
        burn(nft, ctx);
    }

    public(package) fun mint_nft(
        name: String,
        symbol: String,
        description: String,
        image_url: vector<u8>,
        attribute_keys: vector<ascii::String>,
        attribute_values: vector<ascii::String>,
        wallet_address: address,
        ctx: &mut TxContext
    ): EarlyContributorPass {
        let attributes = attributes::new_from_vec(attribute_keys, attribute_values);

        let nft = EarlyContributorPass {
            id: object::new(ctx),
            name,
            symbol,
            description,
            image_url: image_url.to_url(),
            attributes,
        };

        event::emit(MintedNftEvent {
            nftId: object::id(&nft),
            wallet_address,
        });

        nft
    } 

    fun burn(
        nft: EarlyContributorPass,
        _ctx: &mut TxContext,
    ) {
        let EarlyContributorPass { id, name:_, symbol: _, description: _, image_url: _, attributes: _ } = nft;
        
        event::emit(BurnedNftEvent {
            nftId: id.uid_to_inner(),
            wallet_address: _ctx.sender(),
        });

        object::delete(id);
    }
}