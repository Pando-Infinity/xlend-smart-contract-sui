source .env
MODULE="operator"
FUNCTION="init_wormhole_emitter"

echo "Start init system" >> $LOG_PATH
sui client call --package $PACKAGE --module $MODULE --function $FUNCTION --args $OPERATOR_CAP $VERSION $WORMHOLE_STATE --gas-budget $GAS >> $LOG_PATH
echo "End init system" "END"