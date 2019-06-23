git submodule update --remote
cd Entwine
git checkout develop
cd ..

jazzy --config .entwine.yaml
jazzy --config .entwine-test.yaml