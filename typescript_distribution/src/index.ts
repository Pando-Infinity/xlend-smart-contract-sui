import { getFullnodeUrl, SuiClient } from '@mysten/sui.js/client';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import * as fs from 'fs';
import csv from 'csv-parser';

// Your private key in hexadecimal string format (without the '0x' prefix)
const privateKeyHex = '615a7fc7b6e7a1577ab5228c1882dde1fd625e26be468ff3d1afd4684004e0a8'; // Replace with your actual private key

// Convert the hexadecimal string to a Uint8Array
const privateKeyBytes = Uint8Array.from(Buffer.from(privateKeyHex,"hex"));

// Create the keypair from the private key
const keypair = Ed25519Keypair.fromSecretKey(privateKeyBytes);


// Create a new SuiClient object pointing to the network you want to use
const suiClient = new SuiClient({ url: getFullnodeUrl('testnet') });

const packageId = '0xb9a2b156353b24214af4c7a8563cb4e5705e085979436fa2030135d6f1b91114';
const moduleId = 'nft_test';
const functionId = 'mint_to_recipient';
const name = 'Ensofi test';
const description = 'This is a test NFT';
const url = 'https://amaranth-patient-caribou-396.mypinata.cloud/ipfs/QmSxzLWsrvT4yy6D8hpuJTEcRmjrUpkfJA6kF423SQGwgR';
const gasBudget = 10000000;
const txb = new TransactionBlock();


async function mintNFT(address: string) {
    //Add the move call to the transaction block
    txb.moveCall({
        arguments: [
            txb.pure.string(name),
            txb.pure.string(description),
            txb.pure.string(url),
            txb.pure.address(address),
        ],
        target: `${packageId}::${moduleId}::${functionId}`,
    });
    txb.setGasBudget(gasBudget);
   
    
    const response = await suiClient.signAndExecuteTransactionBlock({ signer: keypair, transactionBlock: txb });
    console.log('Transaction response:', response);

}


function distributeNft() {
    const csvFilePath = '../typescript_distribution/utils/wallet_address.csv';

    fs.createReadStream(csvFilePath)
    .pipe(csv())
    .on('data', (row: { [x: string]: any; }) => {
        const walletAddress = row['Wallet address'];

        let walletAddresses = walletAddress.split('\n').filter((address: string) => address.trim() !== '');
        // Iterate through each wallet address
        walletAddresses.forEach(async (walletAddress: string) => {
            await mintNFT(walletAddress);
        });
    })
    .on('end', () => {
        console.log('CSV file successfully processed');
    });
}

// Call the main function
distributeNft();;