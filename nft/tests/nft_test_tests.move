// /*
// #[test_only]
// module nft_test::nft_test_tests {
//     // uncomment this line to import the module
//     // use nft_test::nft_test;

//     const ENotImplemented: u64 = 0;

//     #[test]
//     fun test_nft_test() {
//         // pass
//     }

//     #[test, expected_failure(abort_code = ::nft_test::nft_test_tests::ENotImplemented)]
//     fun test_nft_test_fail() {
//         abort ENotImplemented
//     }
// }
// */
// #[test_only]
// #[allow(duplicate_alias, unused_use, unused_function)]
// module nft_test::nft_test_tests {

//     use 0x0::nft_test;
//     use sui::url::{Self, Url};
//     use sui::tx_context;
//     use std::string;

//     public fun init_for_testing(ctx: &mut TxContext) {
//         init(ctx);
//     }

    
//     // Test minting a new NFT
//     #[test]
//     fun test_mint_to_sender() {
//         // Mock transaction context
//         let ctx = tx_context::new();
       

//         let name = b"Test NFT";
//         let description = b"This is a test NFT";
//         let url = b"https://example.com/test_nft";

//         // Call the mint_to_sender function
//         // nft_test::nft_test::mint_to_sender(name, description, url, &mut ctx);
//         nft_test::mint_to_sender(name, description, url, &mut ctx);

//         // Get the newly minted NFT
//         let nft = nft_test::DevNetNFT::get(ctx.sender());
        
//         // Assert that the NFT has been minted with the correct data
//         assert!(nft.name == string::utf8(name), 0);
//         assert!(nft.description == string::utf8(description), 1);
//         assert!(nft.url == url::new_unsafe_from_bytes(url), 2);
//     }

//     // Test transferring an NFT
//     // fun test_transfer() {
//     //     // Mock transaction context
//     //     let ctx = TxContext::new(TxMetadata::default());

//     //     // Define test data
//     //     let name = b"Test NFT".to_vec();
//     //     let description = b"This is a test NFT".to_vec();
//     //     let url = b"https://example.com/test_nft".to_vec();

//     //     // Mint a new NFT
//     //     nft_test::mint_to_sender(name.clone(), description.clone(), url.clone(), &mut ctx);

//     //     // Get the newly minted NFT
//     //     let nft = nft_test::DevNetNFT::get(ctx.sender());
        
//     //     // Define recipient address
//     //     let recipient: address = 0x087f6f2e71d60c75c92e077b8a939c535fd6aa9f59e849302ba2635b841a7b3d;

//     //     // Call the transfer function
//     //     nft_test::transfer(nft, recipient, &mut ctx);
        
//     //     // Assert that the NFT has been transferred successfully
//     //     assert(nft_test::DevNetNFT::get(recipient).is_some());
//     // }

//     // Add more unit tests as needed

// }
