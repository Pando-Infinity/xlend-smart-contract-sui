import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { RPC_URL, VERSION, OPERATOR_PRIVATE_KEY, UPGRADED_PACKAGE, LEND_COIN_TYPE, OPERATOR_CAP } from './environment.js';
import { getSignerByPrivateKey } from './common.js';

const LENDER_FEE_PERCENT = 500;
const BORROWER_FEE_PERCENT = 500;
const MIN_HEALTH_RATIO = 11000;
const HOT_WALLET = "0x7d8e23c6ca764d6012310907a2b5b936e127ef93547ae8a7424cea776e90772b";
const PRICE_TIME_THRESHOLD = 90;

const initSystem = async () => {
    const suiClient = new SuiClient({ url: RPC_URL });
    const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

    const tx = new TransactionBlock();
    tx.moveCall({
        target: `${UPGRADED_PACKAGE}::operator::init_system`,
        typeArguments: [LEND_COIN_TYPE],
        arguments: [
            tx.object(OPERATOR_CAP),
            tx.object(VERSION),
            tx.pure.u64(LENDER_FEE_PERCENT),
            tx.pure.u64(BORROWER_FEE_PERCENT),
            tx.pure.u64(MIN_HEALTH_RATIO),
            tx.pure.address(HOT_WALLET),
            tx.pure.u64(PRICE_TIME_THRESHOLD),
        ]
    })

    const res = await suiClient.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer,
    });

    console.log({ response: res }, 'Init system');
}

initSystem()