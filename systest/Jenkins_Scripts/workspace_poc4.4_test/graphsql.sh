pwd
whoami
ls
cp poc4.4_base-1-9-2017.bin ~/
cp graph_schema_test.gsql ~/
cp test.csv ~/
cd /home/graphsql
TOKEN='C79E7B2816A0D51F6933D1E8B8EE6F457F4A7E06'
GIT_TOKEN=$(echo $TOKEN |tr '97531' '13579' |tr 'FEDCBA' 'abcdef')
curl -H "Authorization: token $GIT_TOKEN" -L https://api.github.com/repos/GraphSQL/gium/tarball/4.4 > gium.tar.gz
tar xzf gium.tar.gz
cd GraphSQL-gium*
pwd
bash install.sh
source /home/graphsql/.bashrc
cd ..
rm -rf GraphSQL-gium*
rm -rf gium.tar.gz
ls -la /home/*
echo -ne y '\n'n '\n'y'\n' | gadmin --configure dummy
#gadmin --configure dummy
gadmin --set license.key "0b6aeffe39570998eb2ec764561bcbb510d5ec83c710fc6ac45c2b7672b6d94b1486166737" -f
bash poc4.4_base-1-9-2017.bin -y
gadmin config-apply
gadmin restart -y
gsql graph_schema_test.gsql
gadmin status -v graph
curl -X GET "http://localhost:9000/graph/vertices/account"
curl -X GET "http://localhost:9000/graph/vertices/actorIP"
