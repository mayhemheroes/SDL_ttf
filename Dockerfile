# Build Stage
FROM --platform=linux/amd64 ubuntu:20.04 as builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y git clang cmake make libsdl2-dev

## Add source code to the build stage.
WORKDIR /
RUN git clone --recurse-submodules https://github.com/capuanob/SDL_ttf.git
WORKDIR SDL_ttf
RUN git checkout mayhem

## Build
RUN mkdir build
WORKDIR build
RUN CC=clang CFLAGS="-fPIC" cmake -DINSTRUMENT=1 ..
RUN make -j$(nproc)

## Package Stage
FROM --platform=linux/amd64 ubuntu:20.04
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y libsdl2-dev
COPY --from=builder /SDL_ttf/build/fuzz/SDL2_ttf-fuzzer /SDL2_ttf-fuzzer
COPY --from=builder /SDL_ttf/fuzz/corpus /corpus

## Set up fuzzing!
ENTRYPOINT []
CMD /SDL2_ttf-fuzzer /corpus -close_fd_mask=2
