
git clone https://github.com/tcldr/Entwine
git clone https://github.com/tcldr/EntwineRx

rm README.md
cp Entwine/README.md README.md

jazzy --config .entwine.yaml
jazzy --config .entwine-test.yaml
jazzy --config .entwine-rx.yaml

rm -rf ./Entwine
rm -rf ./EntwineRx