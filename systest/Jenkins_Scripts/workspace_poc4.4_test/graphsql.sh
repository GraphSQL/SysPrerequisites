pwd
whoami
ls
cp poc4.4_base-1-9-2017.bin ~/
cp graph_schema_test.gsql ~/
cp test.csv ~/
cd /home/graphsql
curl -H 'Authorization: token 84d37c434950e7e54339057e93af72de79728ba7' -L https://api.github.com/repos/GraphSQL/gium/tarball/4.4_install > gium.tar.gz
tar xzf gium.tar.gz
cd GraphSQL-gium*
pwd
./install.sh
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
