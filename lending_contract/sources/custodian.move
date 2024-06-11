module lending_contract::custodian {
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin::{Self};

    friend lending_contract::admin;
    friend lending_contract::operator;
    friend lending_contract::loan;

    struct Custodian<phantom T> has key, store {
        id: UID,
        treasury_balance: Balance<T>,
    }

    public(friend) fun new<T>(ctx: &mut TxContext) {
        let custodian = Custodian<T> {
            id: object::new(ctx),
            treasury_balance: balance::zero<T>(),
        };

        transfer::share_object(custodian);
    }

    public(friend) fun add_treasury_balance<T>(
        custodian: &mut Custodian<T>,
        amount: Balance<T>,
    ) {
        balance::join(&mut custodian.treasury_balance, amount);
    }

    #[allow(lint(self_transfer))]
    public(friend) fun withdraw_treasury_balance<T>(
        custodian: &mut Custodian<T>,
        ctx: &mut TxContext,
    ) {
        let receive = tx_context::sender(ctx);
        let balance = balance::withdraw_all(&mut custodian.treasury_balance);
        let coin = coin::from_balance(balance, ctx);
        transfer::public_transfer(coin, receive);
    }
}