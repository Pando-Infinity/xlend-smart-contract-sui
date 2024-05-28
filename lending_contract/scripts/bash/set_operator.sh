source .env
MODULE="admin"
FUNCTION="set_operator"
ADDRESS="0x4836f258cbac78c06040309b9dafa6609e46f1d44dc60e370a3d6330880fb0d1"

echo "Set Operator " $ADDRESS >> $LOG_PATH
sui client call --package $PACKAGE --module $MODULE --function $FUNCTION --args $VERSION $ADMIN_CAP $ADDRESS --gas-budget $GAS >> $LOG_PATH
echo "Set Operator " $ADDRESS "END"