import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { RPC_URL, VERSION, OPERATOR_PRIVATE_KEY, UPGRADED_PACKAGE, OPERATOR_CAP } from './environment.js';
import { getSignerByPrivateKey } from './common.js';


const NAME = "EnsoFi Early Contributor Pass";
const SYMBOL = "ENSO";
const DESCRIPTION = "This NFT pass is required for early access to EnsoFi on Sui";
const IMAGE_URL = "https://blush-deep-leech-408.mypinata.cloud/ipfs/QmSQVYcwQ8bLGxfqWTgRY3xceAw4CgAn9Fd7iFWD8TcH1M";
const ATTRIBUTE_KEYS = [];
const ATTRIBUTE_VALUES = [];
const RECEIVER = '0x465370ebd8b13a08d34d92fc6911fa98869c85931135339ad1f858090022635b';

export const mint_nft_to_address = async () => {
    const suiClient = new SuiClient({ url: RPC_URL });
    const signer = getSignerByPrivateKey(OPERATOR_PRIVATE_KEY);

    const tx = new TransactionBlock();
    const functionTarget = `${UPGRADED_PACKAGE}::operator::mint_nft_to_address`
    tx.moveCall({
        target: functionTarget,
        arguments: [
            tx.object(OPERATOR_CAP),
            tx.object(VERSION),
            tx.pure.string(NAME),
            tx.pure.string(SYMBOL),
            tx.pure.string(DESCRIPTION),
            tx.pure.string(IMAGE_URL),
            tx.pure(ATTRIBUTE_KEYS),
            tx.pure(ATTRIBUTE_VALUES),
            tx.pure.address(RECEIVER),
        ]
    });

    const res = await suiClient.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer,
    });

    console.log({ response: res }, 'Mint Nft to address');
}

mint_nft_to_address();