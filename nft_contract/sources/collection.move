module nft_contract::collection {
    use sui::{
        package::Publisher,
        url::Url,
        display,
    };
    use std::string::String;

    use fun std::string::utf8 as vector.to_string;
    use fun sui::url::new_unsafe_from_bytes as vector.to_url;

    const NAME: vector<u8> = b"EnsoFi Early Contributor Pass";
    const SYMBOL: vector<u8> = b"ENSO";
    const IMAGE_URL: vector<u8> = b"https://blush-deep-leech-408.mypinata.cloud/ipfs/QmV2bapSygGLsF8xTQYcQfa5f2PriNVV2SqJbAGupy42s3";
    const PROJECT_URL: vector<u8> = b"https://app.ensofi.xyz";

    public struct Collection has key, store {
        id: UID,
        name: String,
        symbol: String,
        image_url: Url,
        project_url: Url,
    }

    public(package) fun new(
        ctx: &mut TxContext
    ): Collection {
        Collection {
            id: object::new(ctx),
            name: NAME.to_string(),
            symbol: SYMBOL.to_string(),
            image_url: IMAGE_URL.to_url(),
            project_url: PROJECT_URL.to_url(),
        }
    }

    #[allow(lint(self_transfer))]
    public(package) fun display(
        publisher: &Publisher,
        ctx: &mut TxContext
    ) {
        let keys = vector[
            b"name".to_string(),
            b"symbol".to_string(),
            b"url".to_string(),
            b"image_url".to_string(),
            b"project_url".to_string(),
        ];
        let values = vector[
            b"{name}".to_string(),
            b"{symbol}".to_string(),
            b"{image_url}".to_string(),
            b"{image_url}".to_string(),
            b"{project_url}".to_string(),
        ];
        let display = display::new_with_fields<Collection>(
            publisher, keys, values, ctx,
        );
        transfer::public_transfer(display, @admin);
    }
}