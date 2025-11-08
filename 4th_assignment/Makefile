ifndef NS3_PATH
$(error Need NS3_PATH. Please specify the path to your NS3 root directory. E.g., make <target> NS3_PATH=<your path to ns3 root>)
endif
NS3_PATH_ABS := $(shell cd $(NS3_PATH) && pwd)
DIMG_NAME=npa-ns3
# Map the NS3_PATH into the docker container. This ensures that the compile_commands.json has 
# the correct paths such that the LSP on the host can still resolve the symbols correctly.
DCMD=docker run --rm -v $(NS3_PATH_ABS):/$(NS3_PATH_ABS) -w $(NS3_PATH_ABS) $(DIMG_NAME):latest
# One of the following: optimized, debug. Debug will print more outputs.
BUILD_PROFILE=debug 

build_docker_image: Dockerfile
	docker build . -t $(DIMG_NAME)


build_ns3: build_docker_image
	$(DCMD) bash -c "\
		./ns3 configure --enable-examples --build-profile=$(BUILD_PROFILE) --disable-tests && \
		./ns3 build \
		"

run: 
ifndef SCRIPT
	$(error No script provided. Usage: make run SCRIPT=your-script.)
endif
	$(DCMD) bash -c " \
		./ns3 run $(SCRIPT) \
		"
