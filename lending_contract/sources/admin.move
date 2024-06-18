module lending_contract::admin {
    use sui::tx_context::{TxContext};
    use sui::object::{Self, UID};
    use sui::transfer::{Self};

    use lending_contract::operator::{Self};
    use lending_contract::custodian::{Self, Custodian};
    use lending_contract::configuration::{Self, Configuration};
    use lending_contract::state::{Self};
    use lending_contract::version::{Self, Version};

    struct AdminCap has key {
        id: UID,
    }

    fun init(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        transfer::transfer(admin_cap, @admin);
    }

    public entry fun set_admin(
        version: &Version,
        _: &AdminCap,
        user_address: address,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        transfer::transfer(admin_cap, user_address);
    }

    public entry fun set_operator(
        version: &Version,
        _: &AdminCap,
        user_address: address,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);
        operator::new_operator(user_address, ctx);
    }

    public entry fun update_configuration(
        version: &Version,
        _: &AdminCap,
        configuration: &mut Configuration,
        lender_fee_percent: u64,
        borrower_fee_percent: u64,
        min_health_ratio: u64, 
        wallet: address,
        price_time_threshold: u64,
    ) {
        version::assert_current_version(version);
        configuration::update(
            configuration,
            lender_fee_percent,
            borrower_fee_percent,
            min_health_ratio,
            wallet,
            price_time_threshold,
        );
    }

    public entry fun withdraw_treasury_balance<T>(
        version: &Version,
        _: &AdminCap,
        custodian: &mut Custodian<T>,
        ctx: &mut TxContext,
    ) {
        version::assert_current_version(version);
        custodian::withdraw_treasury_balance(
            custodian,
            ctx,
        );
    }
}