source .env
MODULE="operator"
FUNCTION="init_system"

echo "Start init system" >> $LOG_PATH
sui client call --package $PACKAGE --module $MODULE --function $FUNCTION --type-args $TYPE_ARG --args $OPERATOR_CAP $VERSION  --gas-budget $GAS >> $LOG_PATH
echo "End init system" "END"