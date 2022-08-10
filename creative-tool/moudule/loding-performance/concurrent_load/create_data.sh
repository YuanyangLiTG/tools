#!/bin/bash
index=$1
COUNT=$2
cwd=$(cd `dirname $0` && pwd)
cd $cwd
source ./INPUT

rm -rf $DATA_PATH
mkdir -p $DATA_PATH/tpch_data
rm -rf tpch_2_17_0*
curl --fail -s -O https://tigergraph-benchmark-dataset.s3-us-west-1.amazonaws.com/TPCH/tpch_2_17_0.tar.gz
mv tpch_2_17_0.tar.gz $DATA_PATH
cd $DATA_PATH
tar xzf tpch_2_17_0.tar.gz
cd tpch_2_17_0/dbgen
make -f makefile
if [ $COUNT -eq 1 ];then
  ./dbgen -f -s $DATA_SIZE -C $COUNT > /dev/null 2>&1
  echo "Files generated: "
  ls *.tbl
  mv *.tbl $DATA_PATH/tpch_data/
else
  ./dbgen -f -s $DATA_SIZE -S ${index} -C $COUNT > /dev/null 2>&1
  mv nation.tbl $DATA_PATH/tpch_data/
  mv region.tbl $DATA_PATH/tpch_data/
  mv *.tbl.${index} $DATA_PATH/tpch_data/
  cd $DATA_PATH/tpch_data
  mv customer.tbl.${index} customer.tbl
  mv lineitem.tbl.${index} lineitem.tbl
  mv orders.tbl.${index} orders.tbl
  mv partsupp.tbl.${index} partsupp.tbl
  mv part.tbl.${index} part.tbl
  mv supplier.tbl.${index} supplier.tbl
  echo "Files generated: "
  ls *.tbl
fi
