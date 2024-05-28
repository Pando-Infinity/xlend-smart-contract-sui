#! /bin/bash
source .env
echo "Start build" >> $LOG_PATH
sui move build >> $LOG_PATH
echo "Start upgrade" >> $LOG_PATH
sui client upgrade --upgrade-capability $UPGRADE_CAP --gas-budget $GAS --skip-dependency-verification >> $LOG_PATH