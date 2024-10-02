OUTPUT=target/manetu-playbooks.tgz

all: build

build: $(OUTPUT)

target:
	mkdir $@

$(OUTPUT): target *
	@echo "Building archive: $@"
	@(tar -zc -X .tarignore *) > $@

clean:
	@-rm -rf target

