import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { RPC_URL, OPERATOR_PRIVATE_KEY } from './environment.js';
import { getSignerByPrivateKey } from './common.js';

const faucet = async () => {
    const suiClient = new SuiClient({ url: RPC_URL });
    const signer = getSignerByPrivateKey('suiprivkey1qprfwcfqj3sr6vy2u9ptk74asc5astday9xlr8nryft97saqr0ut69qefa2');

    const coinType = '0x8ac626e474c33520a815175649fefcbb272678c8c37a7b024e7171fa45d47711::usdc::USDC';
    const amount = 1000000000000000000;

    const tx = new TransactionBlock();
    const funcTarget = '0x0000000000000000000000000000000000000000000000000000000000000002::coin::mint_and_transfer';
    tx.moveCall({
        target: funcTarget,
        typeArguments: [coinType],
        arguments: [
            tx.object('0x6bad1a88caef6f9ea56680cd31315b2cfeb6018b105471320407559042e6d067'),
            tx.pure.u64(amount),
            tx.pure.address('0x5fe2415c93cfd6251e579dfbd4f609795a0c917f33c40e82aaba5aec698d8769')
        ]
    });
    tx.setGasBudget(200000000)
    
    const res = await suiClient.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer,
    });

    console.log({ response: res }, 'mint faucet coin');
}

faucet();