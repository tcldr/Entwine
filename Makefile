update-docs: generate-docs publish-docs

generate-docs: generate-entwine-docs generate-entwine-rx-docs

publish-docs:
	git add . && git commit -am "auto-publish docs" && git push
		
generate-entwine-docs:
	git clone https://github.com/tcldr/Entwine && \
	rm README.md && cp Entwine/README.md README.md && \
	jazzy --config .entwine.yaml && \
	jazzy --config .entwine-test.yaml && \
	rm -rf ./Entwine
	
generate-entwine-rx-docs:
	git clone https://github.com/tcldr/EntwineRx && \
	jazzy --config .entwine-rx.yaml && \
	rm -rf ./EntwineRx
