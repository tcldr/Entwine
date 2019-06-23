git submodule update --remote
cd Entwine
git checkout develop
cd ..

rm README.md
cp Entwine/README.md README.md

jazzy --config .entwine.yaml
jazzy --config .entwine-test.yaml