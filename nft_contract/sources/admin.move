module nft_contract::admin {
    use nft_contract::{
        version::Version,
        operator,
    };

    public struct AdminCap has key, store {
        id: UID,
    }

    fun init(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        transfer::transfer(admin_cap, @admin);
    }

    public entry fun set_admin(
        _: &AdminCap,
        version: &Version,
        user_address: address,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        transfer::transfer(admin_cap, user_address);
    }

    public entry fun set_operator(
        _: &AdminCap,
        version: &Version,
        user_address: address,
        ctx: &mut TxContext,
    ) {
        version.assert_current_version();
        operator::new_operator(user_address, ctx);
    }
}