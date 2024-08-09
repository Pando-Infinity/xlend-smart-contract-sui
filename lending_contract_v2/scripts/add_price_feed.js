import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { RPC_URL, VERSION, OPERATOR_PRIVATE_KEY, UPGRADED_PACKAGE, LEND_COIN_TYPE, OPERATOR_CAP, CONFIGURATION } from './environment.js';
import { getSignerByPrivateKey } from './common.js';

const COIN_SYMBOL = "SOL";
const COIN_PRICE_FEED_ID = "0xfe650f0367d4a7ef9815a593ea15d36593f0643aaaf0149bb04be67ab851decd";

const addPriceFeedId = async () => {
    const suiClient = new SuiClient({ url: RPC_URL });
    const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

    const tx = new TransactionBlock();
    tx.moveCall({
        target: `${UPGRADED_PACKAGE}::operator::add_price_feed_id`,
        arguments: [
            tx.object(OPERATOR_CAP),
            tx.object(VERSION),
            tx.object(CONFIGURATION),
            tx.pure.string(COIN_SYMBOL),
            tx.pure.string(COIN_PRICE_FEED_ID),
        ]
    })

    const res = await suiClient.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer,
    });

    console.log({ response: res }, 'Add price feed id');
}

addPriceFeedId()