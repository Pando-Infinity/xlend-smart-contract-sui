#! /bin/bash
source .env
echo "Start build" >> $LOG_PATH
sui move build >> $LOG_PATH
GAS=300000000
echo "Start publish" >> $LOG_PATH
sui client publish --gas-budget $GAS --skip-dependency-verification --skip-fetch-latest-git-deps >> $LOG_PATH
